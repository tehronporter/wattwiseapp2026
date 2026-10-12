import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ success: false, error: { message: "Method not allowed" } }, 405);

  const startedAt = Date.now();
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ success: false, error: { message: "Unauthorized" } }, 401);
    const supabase = createClient(supabaseUrl, supabaseKey);
    const { data: { user } } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (!user) return json({ success: false, error: { message: "Unauthorized" } }, 401);

    const body = await req.json();
    const attemptId = typeof body.quiz_attempt_id === "string" ? body.quiz_attempt_id : null;
    const questionId = typeof body.question_id === "string" ? body.question_id : null;
    const selected = typeof body.selected === "string" ? body.selected : null;
    const flagged = body.flagged === true;
    const responseMs = Number.isFinite(Number(body.response_ms)) ? Math.max(0, Math.trunc(Number(body.response_ms))) : null;
    if (!attemptId || !questionId || !selected) return json({ success: false, error: { message: "Missing answer fields" } }, 400);

    const { data: attempt } = await supabase
      .from("quiz_attempts")
      .select("id, quiz_id, completed_at")
      .eq("id", attemptId)
      .eq("user_id", user.id)
      .maybeSingle();
    if (!attempt) return json({ success: false, error: { message: "Quiz attempt not found" } }, 404);
    if (attempt.completed_at) return json({ success: false, error: { message: "This set is already complete" } }, 409);

    const { data: assignment } = await supabase
      .from("quiz_question_assignments")
      .select("practice_question_id")
      .eq("quiz_id", attempt.quiz_id)
      .eq("practice_question_id", questionId)
      .maybeSingle();
    if (!assignment) return json({ success: false, error: { message: "Question is not part of this set" } }, 403);

    const { data: question, error: questionError } = await supabase
      .from("practice_questions")
      .select("id, topic_slug, correct_choice, choices, explanation, nec_reference, disclaimer")
      .eq("id", questionId)
      .eq("is_active", true)
      .eq("publish_status", "published")
      .single();
    if (questionError || !question) return json({ success: false, error: { message: "Question unavailable" } }, 404);

    const isCorrect = selected === question.correct_choice;
    const { data: existingAttempt } = await supabase
      .from("question_attempts")
      .select("selected_choice, is_correct")
      .eq("quiz_attempt_id", attemptId)
      .eq("question_id", questionId)
      .maybeSingle();

    if (!existingAttempt) {
      const { error: insertError } = await supabase.from("question_attempts").insert({
        user_id: user.id,
        quiz_attempt_id: attemptId,
        question_id: questionId,
        selected_choice: selected,
        is_correct: isCorrect,
        response_ms: responseMs,
        flagged,
      });
      if (insertError) throw insertError;

      const { data: current } = await supabase
        .from("topic_mastery")
        .select("score, attempts_count, correct_count")
        .eq("user_id", user.id)
        .eq("topic_slug", question.topic_slug)
        .maybeSingle();
      const previousScore = Number(current?.score ?? 0.5);
      const score = Math.max(0, Math.min(1, previousScore * 0.8 + (isCorrect ? 1 : 0) * 0.2));
      const intervalDays = isCorrect ? (score >= 0.8 ? 14 : score >= 0.65 ? 7 : 3) : 1;
      const dueAt = new Date(Date.now() + intervalDays * 86_400_000).toISOString();
      const { error: masteryError } = await supabase.from("topic_mastery").upsert({
        user_id: user.id,
        topic_slug: question.topic_slug,
        score,
        attempts_count: Number(current?.attempts_count ?? 0) + 1,
        correct_count: Number(current?.correct_count ?? 0) + (isCorrect ? 1 : 0),
        due_at: dueAt,
        formula_version: "weighted_accuracy_v1",
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id,topic_slug" });
      if (masteryError) throw masteryError;
    }

    console.log(JSON.stringify({ level: "info", message: "answer_submitted", user_id: user.id, quiz_attempt_id: attemptId, question_id: questionId, duration_ms: Date.now() - startedAt }));
    return json({ success: true, data: {
      is_correct: existingAttempt?.is_correct ?? isCorrect,
      correct_choice: question.correct_choice,
      correct_answer: question.choices[question.correct_choice],
      explanation: question.explanation,
      reference_code: question.nec_reference,
      disclaimer: question.disclaimer,
    } });
  } catch (error) {
    console.error(JSON.stringify({ level: "error", message: "submit_answer_failed", error: error instanceof Error ? error.message : String(error), duration_ms: Date.now() - startedAt }));
    return json({ success: false, error: { message: "Internal server error" } }, 500);
  }
});
