import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Verify token and get user
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const userId = user.id;
    const { quiz_id, answers } = await req.json();

    if (!quiz_id || !answers || !Array.isArray(answers)) {
      return new Response(
        JSON.stringify({ error: "Missing quiz_id or answers" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Get quiz questions
    const { data: questions, error: qError } = await supabase
      .from("quiz_questions")
      .select("id, question_number, question_text, choices, correct_answer, explanation")
      .eq("quiz_id", quiz_id);

    if (qError || !questions) {
      return new Response(JSON.stringify({ error: "Quiz not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Score the quiz
    let correctCount = 0;
    const results = answers.map((answer: any) => {
      const question = questions.find(
        (q: any) => q.question_number === parseInt(answer.question_id.split("-")[1]) + 1
      );
      if (!question) {
        return {
          question_id: answer.question_id,
          question: "Question not found",
          user_answer: answer.selected,
          correct_answer: "",
          explanation: "",
          is_correct: false,
        };
      }

      const isCorrect = answer.selected === question.correct_answer;
      if (isCorrect) correctCount++;

      return {
        question_id: answer.question_id,
        question: question.question_text,
        user_answer: answer.selected,
        correct_answer: question.correct_answer,
        explanation: question.explanation,
        is_correct: isCorrect,
      };
    });

    const score = (correctCount / answers.length) * 100;

    // Identify weak topics (questions answered incorrectly)
    const weakTopics = results
      .filter((r: any) => !r.is_correct)
      .map((r: any) => r.question_id)
      .slice(0, 3);

    // Create quiz attempt record
    const { error: attemptError } = await supabase
      .from("quiz_attempts")
      .insert({
        user_id: userId,
        quiz_id,
        score,
        correct_count: correctCount,
        total_count: answers.length,
      });

    if (attemptError) throw attemptError;

    // Log results
    await supabase.from("quiz_results").insert(
      results.map((r: any) => ({
        user_id: userId,
        quiz_id,
        question_id: r.question_id,
        user_answer: r.user_answer,
        is_correct: r.is_correct,
      }))
    );

    return new Response(
      JSON.stringify({
        score,
        correct_count: correctCount,
        results,
        weak_topics: weakTopics,
      }),
      {
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
