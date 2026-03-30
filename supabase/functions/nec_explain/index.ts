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
    const { nec_id } = await req.json();

    if (!nec_id) {
      return new Response(JSON.stringify({ error: "Missing nec_id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get NEC entry
    const { data: entry, error: entryError } = await supabase
      .from("nec_entries")
      .select("id, section, subsection, title, summary, full_text")
      .eq("id", nec_id)
      .single();

    if (entryError || !entry) {
      return new Response(JSON.stringify({ error: "NEC entry not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Generate explanation using OpenAI
    const prompt = `Provide a detailed but accessible explanation of NEC Article ${entry.section}.${entry.subsection}: "${entry.title}"

Official text: ${entry.full_text || entry.summary}

Explain:
1. What this code section requires
2. Why it exists (safety/practical reasons)
3. Common applications in residential/commercial settings
4. Key points for an apprentice to remember

Keep the explanation 4-6 paragraphs, technical but understandable for someone studying for their electrician exam.`;

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
        max_tokens: 1000,
      }),
    });

    if (!openaiResponse.ok) {
      throw new Error(
        `OpenAI API error: ${openaiResponse.status} ${openaiResponse.statusText}`
      );
    }

    const openaiData = await openaiResponse.json();
    const expanded = openaiData.choices[0].message.content;

    // Log AI request
    await supabase.from("ai_request_logs").insert({
      user_id: userId,
      request_type: "nec_explain",
      prompt: `Explain NEC ${entry.section}.${entry.subsection}`,
      response: expanded,
      tokens_used: 0,
    });

    return new Response(
      JSON.stringify({
        expanded,
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
