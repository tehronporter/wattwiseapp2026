import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const openaiKey = Deno.env.get("OPENAI_API_KEY");

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function fallbackExplanation(entry: {
  reference_code: string;
  title: string;
  simplified_summary: string;
  topic_notes: string | null;
}) {
  const notes = entry.topic_notes?.trim();
  if (notes) {
    return notes;
  }

  return [
    `${entry.title} in NEC ${entry.reference_code} is about the installation decision described in the summary.`,
    entry.simplified_summary,
    "For exam prep, focus on what hazard, equipment condition, or design choice the section is trying to control.",
    "If a question sounds close, go back to the article scope and the exact installation context before choosing an answer.",
  ].join(" ");
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

    const { nec_id } = await req.json();
    if (!nec_id) {
      return json({ success: false, error: { message: "Missing nec_id" } }, 400);
    }

    await supabase.from("profiles").upsert(
      {
        id: user.id,
        email: user.email ?? null,
        onboarding_completed: true,
        last_active_at: new Date().toISOString(),
      },
      { onConflict: "id" }
    );

    const { data: entry, error } = await supabase
      .from("nec_entries")
      .select("reference_code, title, simplified_summary, topic_notes")
      .eq("id", nec_id)
      .maybeSingle();

    if (error) throw error;
    if (!entry) {
      return json({ success: false, error: { message: "NEC entry not found" } }, 404);
    }

    let expanded = fallbackExplanation(entry);
    let modelUsed = "fallback";

    if (openaiKey) {
      const prompt = `Explain NEC ${entry.reference_code} (${entry.title}) for an electrician exam student.\n\nKnown simplified summary: ${entry.simplified_summary}\n\nAdditional notes: ${entry.topic_notes ?? "None"}\n\nWrite 4 short paragraphs in plain English that explain:\n1. What the section is generally about\n2. Why the rule matters in practice\n3. What people commonly confuse\n4. What to remember for exam prep\n\nDo not quote copyrighted NEC text. Keep the explanation general, accurate, and supportive.`;

      const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${openaiKey}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.4,
          max_tokens: 700,
        }),
      });

      if (response.ok) {
        const openaiData = await response.json();
        expanded = openaiData.choices?.[0]?.message?.content ?? expanded;
        modelUsed = "gpt-4o-mini";
      }
    }

    await supabase.from("ai_request_logs").insert({
      user_id: user.id,
      request_type: "nec_explanation",
      model_used: modelUsed,
      status: "success",
    });

    return json({
      success: true,
      data: {
        expanded,
      },
    });
  } catch (error) {
    console.error("nec_explain error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500
    );
  }
});
