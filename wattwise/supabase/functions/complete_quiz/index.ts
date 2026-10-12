import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function first<T>(value: T | T[] | null | undefined): T | null {
  return Array.isArray(value) ? value[0] ?? null : value ?? null;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ success: false, error: { message: "Method not allowed" } }, 405);
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ success: false, error: { message: "Unauthorized" } }, 401);
    const supabase = createClient(supabaseUrl, supabaseKey);
    const { data: { user } } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (!user) return json({ success: false, error: { message: "Unauthorized" } }, 401);
    const body = await req.json();
    const attemptId = typeof body.quiz_attempt_id === "string" ? body.quiz_attempt_id : null;
    if (!attemptId) return json({ success: false, error: { message: "Missing quiz_attempt_id" } }, 400);

    const { data: attempt } = await supabase.from("quiz_attempts").select("id, quiz_id, completed_at").eq("id", attemptId).eq("user_id", user.id).maybeSingle();
    if (!attempt) return json({ success: false, error: { message: "Quiz attempt not found" } }, 404);

    const { data: existing } = await supabase.from("quiz_results").select("score, correct_count, total_count, results_json, weak_topics").eq("quiz_attempt_id", attemptId).eq("user_id", user.id).maybeSingle();
    if (existing) return json({ success: true, data: { quiz_attempt_id: attemptId, ...existing } });

    const { data: assigned, count: assignedCount } = await supabase
      .from("quiz_question_assignments")
      .select("practice_question_id", { count: "exact" })
      .eq("quiz_id", attempt.quiz_id);
    const { data: answerRows, error: answersError } = await supabase
      .from("question_attempts")
      .select(`
        question_id, selected_choice, is_correct,
        practice_questions (question_text, choices, correct_choice, explanation, topic_slug, topic_title, nec_reference)
      `)
      .eq("quiz_attempt_id", attemptId)
      .eq("user_id", user.id);
    if (answersError) throw answersError;
    if ((answerRows?.length ?? 0) < (assignedCount ?? assigned?.length ?? 0)) return json({ success: false, error: { message: "Answer every question before completing the set" } }, 409);

    const weakTopics = new Map<string, number>();
    const results = (answerRows ?? []).map((row) => {
      const question = first(row.practice_questions);
      if (!row.is_correct && question) weakTopics.set(question.topic_title, (weakTopics.get(question.topic_title) ?? 0) + 1);
      return {
        question_id: row.question_id,
        question: question?.question_text ?? "Question unavailable",
        user_answer: question?.choices?.[row.selected_choice ?? ""] ?? row.selected_choice ?? "Not answered",
        correct_answer: question?.choices?.[question.correct_choice] ?? question?.correct_choice ?? "",
        explanation: question?.explanation ?? "",
        is_correct: row.is_correct,
        topics: question ? [question.topic_slug] : [],
        topic_titles: question ? [question.topic_title] : [],
        reference_code: question?.nec_reference ?? null,
      };
    });
    const correctCount = results.filter((result) => result.is_correct).length;
    const totalCount = results.length;
    const score = totalCount ? correctCount / totalCount : 0;
    const answers = Object.fromEntries((answerRows ?? []).map((row) => [row.question_id, row.selected_choice]));
    const weakTopicNames = [...weakTopics.entries()].sort((left, right) => right[1] - left[1]).map(([topic]) => topic);

    const completedAt = new Date().toISOString();
    const { error: updateError } = await supabase.from("quiz_attempts").update({ answers, completed_at: completedAt }).eq("id", attemptId).eq("user_id", user.id);
    if (updateError) throw updateError;
    const { error: resultError } = await supabase.from("quiz_results").insert({ quiz_attempt_id: attemptId, user_id: user.id, score, correct_count: correctCount, total_count: totalCount, results_json: results, weak_topics: weakTopicNames });
    if (resultError) throw resultError;

    return json({ success: true, data: { quiz_attempt_id: attemptId, score, correct_count: correctCount, total_count: totalCount, results, weak_topics: weakTopicNames } });
  } catch (error) {
    console.error("complete_quiz error:", error);
    return json({ success: false, error: { message: "Internal server error" } }, 500);
  }
});

