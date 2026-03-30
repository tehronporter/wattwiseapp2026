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
    const { message, context } = await req.json();

    if (!message) {
      return new Response(JSON.stringify({ error: "Missing message" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Check subscription status for daily limits
    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("tier")
      .eq("user_id", userId)
      .single();

    const isPro = subscription?.tier === "pro";

    // Check daily tutor message usage
    const today = new Date().toISOString().split("T")[0];
    const { data: usageData } = await supabase
      .from("ai_usage_counters")
      .select("daily_tutor_messages")
      .eq("user_id", userId)
      .eq("usage_date", today)
      .single();

    const messagesUsed = usageData?.daily_tutor_messages || 0;
    const limit = isPro ? -1 : 5; // -1 means unlimited for pro

    if (limit !== -1 && messagesUsed >= limit) {
      return new Response(
        JSON.stringify({
          error: "Daily tutor message limit reached",
          limit,
          used: messagesUsed,
        }),
        {
          status: 429,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Get lesson context if provided
    let lessonContext = "";
    if (context && context.type === "lesson" && context.id) {
      const { data: lesson } = await supabase
        .from("lessons")
        .select("title, description")
        .eq("id", context.id)
        .single();

      if (lesson) {
        lessonContext = `Student is learning about: ${lesson.title}. ${lesson.description}. `;
      }
    }

    // Build system prompt
    const systemPrompt = `You are an expert NEC (National Electrical Code) tutor helping electrician apprentices prepare for their exams.
${lessonContext}
Provide clear, concise explanations focused on NEC code sections and practical application.
Keep responses to 2-3 sentences unless asked for more detail.
Suggest 1-2 follow-up questions the student might find helpful.
If the question is about a specific NEC section, reference the code when possible.`;

    // Call OpenAI
    const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${openaiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        system: systemPrompt,
        messages: [
          {
            role: "user",
            content: message,
          },
        ],
        temperature: 0.7,
        max_tokens: 500,
      }),
    });

    if (!openaiResponse.ok) {
      throw new Error(
        `OpenAI API error: ${openaiResponse.status} ${openaiResponse.statusText}`
      );
    }

    const openaiData = await openaiResponse.json();
    const answer = openaiData.choices[0].message.content;

    // Extract follow-ups and steps from response (optional enhancement)
    const followUps = [
      "Can you explain this in more detail?",
      "How does this apply in practice?",
    ];
    const steps = undefined;

    // Log AI request
    await supabase.from("ai_request_logs").insert({
      user_id: userId,
      request_type: "tutor",
      prompt: message,
      response: answer,
      tokens_used: 0, // Would need to calculate from response
    });

    // Increment daily counter
    if (usageData) {
      await supabase
        .from("ai_usage_counters")
        .update({ daily_tutor_messages: messagesUsed + 1 })
        .eq("user_id", userId)
        .eq("usage_date", today);
    } else {
      await supabase.from("ai_usage_counters").insert({
        user_id: userId,
        usage_date: today,
        daily_tutor_messages: 1,
      });
    }

    return new Response(
      JSON.stringify({
        answer,
        steps,
        follow_ups: followUps,
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
