import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

type PracticeQuestion = {
  id: string;
  source_key: string;
  certification_level: string;
  topic_slug: string;
  topic_title: string;
  question_text: string;
  choices: Record<string, string>;
};

function uniqueById(rows: PracticeQuestion[]) {
  const seen = new Set<string>();
  return rows.filter((row) => {
    if (seen.has(row.id)) return false;
    seen.add(row.id);
    return true;
  });
}

function selectAdaptiveQuestions(
  candidates: PracticeQuestion[],
  questionCount: number,
  requestedTopics: string[],
  recentQuestionIds: Set<string>,
  mastery: Map<string, number>,
) {
  const score = (question: PracticeQuestion) => {
    const topicBoost = requestedTopics.includes(question.topic_slug) ? 4 : 0;
    const masteryBoost = (1 - (mastery.get(question.topic_slug) ?? 0.5)) * 2;
    const freshnessBoost = recentQuestionIds.has(question.id) ? -5 : 1;
    return topicBoost + masteryBoost + freshnessBoost + Math.random();
  };

  return candidates
    .map((question) => ({ question, rank: score(question) }))
    .sort((left, right) => right.rank - left.rank)
    .map(({ question }) => question)
    .slice(0, questionCount);
}

async function fetchQuestions(
  supabase: ReturnType<typeof createClient>,
  {
    examType,
    topicTags,
    requireTopicMatch,
  }: { examType?: string | null; topicTags: string[]; requireTopicMatch: boolean }
) {
  let query = supabase
    .from("practice_questions")
    .select("id, source_key, certification_level, topic_slug, topic_title, question_text, choices")
    .eq("is_active", true)
    .eq("publish_status", "published")
    .order("source_key", { ascending: true });

  if (examType) {
    query = query.eq("certification_level", examType);
  }

  if (requireTopicMatch && topicTags.length > 0) {
    query = query.in("topic_slug", topicTags);
  }

  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as PracticeQuestion[];
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ success: false, error: { message: "Method not allowed" } }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ success: false, error: { message: "Unauthorized" } }, 401);
    }

    const token = authHeader.replace("Bearer ", "");
    const supabase = createClient(supabaseUrl, supabaseKey);

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ success: false, error: { message: "Unauthorized" } }, 401);
    }

    const body = await req.json();
    const quizType = typeof body.quiz_type === "string" ? body.quiz_type : null;
    const examType = typeof body.exam_type === "string" ? body.exam_type : null;
    const source = typeof body.source === "string" ? body.source.slice(0, 80) : null;
    const topicTags = Array.isArray(body.topic_tags)
      ? body.topic_tags.filter((value: unknown): value is string => typeof value === "string")
      : [];
    const requestedCount = Number(body.question_count);
    const questionCount = Number.isFinite(requestedCount)
      ? Math.max(1, Math.min(Math.trunc(requestedCount), 50))
      : 10;

    if (!quizType) {
      return json(
        { success: false, error: { message: "Missing quiz_type" } },
        400
      );
    }

    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("tier, status, expires_at")
      .eq("user_id", user.id)
      .maybeSingle();

    const hasPaidAccess = (
      (subscription?.tier === "fast_track" || subscription?.tier === "full_prep") &&
      subscription?.status === "active" &&
      (!subscription?.expires_at || new Date(subscription.expires_at).getTime() > Date.now())
    );

    if (!hasPaidAccess) {
      if (quizType !== "quick_quiz") {
        return json(
          { success: false, error: { message: "Preview includes one quick quiz. Choose full access for deeper practice." } },
          403,
        );
      }

      const { count: previewAttempts, error: attemptsError } = await supabase
        .from("quiz_attempts")
        .select("*", { count: "exact", head: true })
        .eq("user_id", user.id);

      if (attemptsError) throw attemptsError;
      if ((previewAttempts ?? 0) >= 1) {
        return json(
          { success: false, error: { message: "You've already used your preview quiz. Choose full access to keep practicing." } },
          403,
        );
      }
    }

    const targeted = await fetchQuestions(supabase, {
      examType,
      topicTags,
      requireTopicMatch: quizType === "weak_area_review",
    });
    const levelScoped = await fetchQuestions(supabase, {
      examType,
      topicTags: [],
      requireTopicMatch: false,
    });
    const allActive = await fetchQuestions(supabase, {
      examType: null,
      topicTags: [],
      requireTopicMatch: false,
    });

    const candidates = uniqueById([
      ...targeted,
      ...levelScoped,
      ...allActive,
    ]);

    const [{ data: recentAttempts }, { data: masteryRows }] = await Promise.all([
      supabase
        .from("question_attempts")
        .select("question_id")
        .eq("user_id", user.id)
        .order("submitted_at", { ascending: false })
        .limit(100),
      supabase
        .from("topic_mastery")
        .select("topic_slug, score")
        .eq("user_id", user.id),
    ]);
    const recentQuestionIds = new Set((recentAttempts ?? []).map((row) => row.question_id as string));
    const mastery = new Map((masteryRows ?? []).map((row) => [row.topic_slug as string, Number(row.score)]));
    const selectedQuestions = selectAdaptiveQuestions(candidates, questionCount, topicTags, recentQuestionIds, mastery);

    if (selectedQuestions.length === 0) {
      return json(
        { success: false, error: { message: "No practice questions are available." } },
        404
      );
    }

    const { data: quizRow, error: quizError } = await supabase
      .from("quizzes")
      .insert({
        user_id: user.id,
        quiz_type: quizType,
        question_count: selectedQuestions.length,
        topic_tags: topicTags,
        source,
      })
      .select("id")
      .single();

    if (quizError || !quizRow) throw quizError;

    const { error: assignmentError } = await supabase
      .from("quiz_question_assignments")
      .insert(
        selectedQuestions.map((question, index) => ({
          quiz_id: quizRow.id,
          practice_question_id: question.id,
          question_number: index + 1,
        }))
      );

    if (assignmentError) throw assignmentError;

    const { data: attemptRow, error: attemptError } = await supabase
      .from("quiz_attempts")
      .insert({ user_id: user.id, quiz_id: quizRow.id })
      .select("id")
      .single();
    if (attemptError || !attemptRow) throw attemptError;

    return json({
      success: true,
      data: {
        quiz_id: quizRow.id,
        quiz_attempt_id: attemptRow.id,
        topic_tags: topicTags,
        source,
        questions: selectedQuestions.map((question) => ({
          id: question.id,
          question: question.question_text,
          choices: question.choices,
          topics: [question.topic_slug],
        })),
      },
    });
  } catch (error) {
    console.error("generate_quiz error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500
    );
  }
});
