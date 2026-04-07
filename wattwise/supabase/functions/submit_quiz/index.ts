import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

type AssignmentRow = {
  question_number: number;
  practice_questions:
    | {
        id: string;
        topic_slug: string;
        topic_title: string;
        question_text: string;
        choices: Record<string, string>;
        correct_choice: string;
        explanation: string;
        nec_reference: string | null;
      }
    | {
        id: string;
        topic_slug: string;
        topic_title: string;
        question_text: string;
        choices: Record<string, string>;
        correct_choice: string;
        explanation: string;
        nec_reference: string | null;
      }[];
};

function firstRelation<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) {
    return value[0] ?? null;
  }
  return value ?? null;
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
    const quizId = typeof body.quiz_id === "string" ? body.quiz_id : null;
    const answers = Array.isArray(body.answers) ? body.answers : [];

    if (!quizId) {
      return json(
        { success: false, error: { message: "Missing quiz_id" } },
        400
      );
    }

    const { data: assignmentRows, error: assignmentError } = await supabase
      .from("quiz_question_assignments")
      .select(`
        question_number,
        practice_questions (
          id,
          topic_slug,
          topic_title,
          question_text,
          choices,
          correct_choice,
          explanation,
          nec_reference
        )
      `)
      .eq("quiz_id", quizId)
      .order("question_number", { ascending: true });

    if (assignmentError) throw assignmentError;

    const assignments = (assignmentRows ?? []) as AssignmentRow[];
    if (assignments.length === 0) {
      return json(
        { success: false, error: { message: "Quiz not found" } },
        404
      );
    }

    const answersByQuestionId = new Map<string, string>(
      answers
        .filter(
          (answer: unknown): answer is { question_id: string; selected: string } =>
            typeof answer === "object" &&
            answer !== null &&
            typeof (answer as { question_id?: unknown }).question_id === "string" &&
            typeof (answer as { selected?: unknown }).selected === "string"
        )
        .map((answer) => [answer.question_id, answer.selected])
    );

    let correctCount = 0;
    const weakTopics = new Map<string, { title: string; count: number }>();
    const results = assignments.map((assignment) => {
      const question = firstRelation(assignment.practice_questions);
      if (!question) {
        return {
          question_id: `missing-${assignment.question_number}`,
          question: "Question unavailable",
          user_answer: "Not answered",
          correct_answer: "",
          explanation: "",
          is_correct: false,
        };
      }

      const selectedKey = answersByQuestionId.get(question.id) ?? null;
      const isCorrect = selectedKey === question.correct_choice;
      if (isCorrect) {
        correctCount += 1;
      } else {
        const existing = weakTopics.get(question.topic_slug) ?? {
          title: question.topic_title,
          count: 0,
        };
        existing.count += 1;
        weakTopics.set(question.topic_slug, existing);
      }

      return {
        question_id: question.id,
        question: question.question_text,
        user_answer: selectedKey ? question.choices[selectedKey] ?? selectedKey : "Not answered",
        correct_answer: question.choices[question.correct_choice] ?? question.correct_choice,
        explanation: question.explanation,
        is_correct: isCorrect,
        topics: [question.topic_slug],
        topic_titles: [question.topic_title],
        reference_code: question.nec_reference,
      };
    });

    const totalCount = assignments.length;
    const score = totalCount > 0 ? correctCount / totalCount : 0;
    const answerPayload = Object.fromEntries(
      answers
        .filter(
          (answer: unknown): answer is { question_id: string; selected: string } =>
            typeof answer === "object" &&
            answer !== null &&
            typeof (answer as { question_id?: unknown }).question_id === "string" &&
            typeof (answer as { selected?: unknown }).selected === "string"
        )
        .map((answer) => [answer.question_id, answer.selected])
    );

    const { data: attemptRow, error: attemptError } = await supabase
      .from("quiz_attempts")
      .insert({
        user_id: user.id,
        quiz_id: quizId,
        completed_at: new Date().toISOString(),
        answers: answerPayload,
      })
      .select("id")
      .single();

    if (attemptError || !attemptRow) throw attemptError;

    const { error: resultError } = await supabase.from("quiz_results").insert({
      quiz_attempt_id: attemptRow.id,
      user_id: user.id,
      score,
      correct_count: correctCount,
      total_count: totalCount,
      results_json: results,
      weak_topics: Array.from(weakTopics.values())
        .sort((lhs, rhs) => rhs.count - lhs.count)
        .map((item) => item.title),
    });

    if (resultError) throw resultError;

    return json({
      success: true,
      data: {
        quiz_attempt_id: attemptRow.id,
        score,
        correct_count: correctCount,
        total_count: totalCount,
        results,
        weak_topics: Array.from(weakTopics.values())
          .sort((lhs, rhs) => rhs.count - lhs.count)
          .map((item) => item.title),
      },
    });
  } catch (error) {
    console.error("submit_quiz error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500
    );
  }
});
