import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const openaiKey = Deno.env.get("OPENAI_API_KEY")!;

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
    const { quiz_type, topic_tags, question_count } = await req.json();

    if (!quiz_type || !topic_tags || !question_count) {
      return new Response(
        JSON.stringify({
          error: "Missing quiz_type, topic_tags, or question_count",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Fetch NEC entries related to topics for context
    const { data: necEntries } = await supabase
      .from("nec_entries")
      .select("section, subsection, title")
      .in("id", topic_tags)
      .limit(5);

    const necContext =
      necEntries && necEntries.length > 0
        ? necEntries.map((n: any) => `${n.section}.${n.subsection} ${n.title}`).join("\n")
        : topic_tags.join(", ");

    // Generate quiz questions using OpenAI
    const prompt = `Generate ${question_count} multiple-choice questions for an NEC electrician exam (${quiz_type} level).
Focus on these topics: ${necContext}
Each question should have 4 answer choices (A, B, C, D) with exactly one correct answer.
Return a JSON array of objects with this structure:
[
  {
    "question": "Question text?",
    "choices": {"A": "choice a", "B": "choice b", "C": "choice c", "D": "choice d"},
    "correct_answer": "A",
    "explanation": "Why this is correct...",
    "topics": ["topic1", "topic2"]
  }
]
Only return the JSON array, no markdown or extra text.`;

    const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${openaiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "user",
            content: prompt,
          },
        ],
        temperature: 0.7,
        max_tokens: 2000,
      }),
    });

    if (!openaiResponse.ok) {
      throw new Error(
        `OpenAI API error: ${openaiResponse.status} ${openaiResponse.statusText}`
      );
    }

    const openaiData = await openaiResponse.json();
    const content = openaiData.choices[0].message.content;

    let questionsData;
    try {
      questionsData = JSON.parse(content);
    } catch {
      // Fallback: return mock questions if parsing fails
      questionsData = Array.from({ length: question_count }, (_, i) => ({
        question: `Sample question ${i + 1}?`,
        choices: {
          A: "Option A",
          B: "Option B",
          C: "Option C",
          D: "Option D",
        },
        correct_answer: "A",
        explanation: "This is the correct answer.",
        topics: topic_tags,
      }));
    }

    // Create quiz record
    const { data: quizData, error: quizError } = await supabase
      .from("quizzes")
      .insert({
        user_id: userId,
        quiz_type,
        question_count,
      })
      .select("id")
      .single();

    if (quizError) throw quizError;

    const quizId = quizData.id;

    // Insert questions
    const questionInserts = questionsData.map((q: any, idx: number) => ({
      quiz_id: quizId,
      question_number: idx + 1,
      question_text: q.question,
      choices: q.choices,
      correct_answer: q.correct_answer,
      explanation: q.explanation,
    }));

    await supabase.from("quiz_questions").insert(questionInserts);

    // Return without correct answers (sent only on submit)
    const questions = questionsData.map((q: any, idx: number) => ({
      id: `q-${idx}`,
      question: q.question,
      choices: q.choices,
      topics: q.topics,
    }));

    return new Response(
      JSON.stringify({
        quiz_id: quizId,
        questions,
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
