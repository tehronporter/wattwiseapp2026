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

    const selectedQuestions = uniqueById([
      ...targeted,
      ...levelScoped,
      ...allActive,
    ]).slice(0, questionCount);

    if (selectedQuestions.length === 0) {
      return json(
        { success: false, error: { message: "No practice questions are available." } },
        404
      );
    }

    const { data: quizRow, error: quizError } = await supabase
      .from("quizzes")
      .insert({
        quiz_type: quizType,
        question_count: selectedQuestions.length,
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

    return json({
      success: true,
      data: {
        quiz_id: quizRow.id,
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
