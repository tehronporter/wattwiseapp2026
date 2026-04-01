import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const openaiKey = Deno.env.get("OPENAI_API_KEY");
const primaryModel = Deno.env.get("AI_NEC_PRIMARY_MODEL") ?? "gpt-4o-mini";
const fallbackModel = Deno.env.get("AI_NEC_FALLBACK_MODEL") ?? "gpt-4.1-mini";
const providerName = "openai";
const promptVersion = "nec_explain_v2";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function normalizedText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

async function countNECExplanations(
  supabase: ReturnType<typeof createClient>,
  userId: string,
) {
  const { count, error } = await supabase
    .from("ai_request_logs")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("request_type", "nec_explanation")
    .eq("status", "success");

  if (error) throw error;
  return count ?? 0;
}

async function callProvider({
  model,
  prompt,
}: {
  model: string;
  prompt: string;
}) {
  if (!openaiKey) {
    throw new Error("OPENAI_API_KEY missing");
  }

  const startedAt = Date.now();
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${openaiKey}`,
    },
    signal: AbortSignal.timeout(20000),
    body: JSON.stringify({
      model,
      temperature: 0.2,
      max_tokens: 700,
      messages: [
        {
          role: "system",
          content: [
            "You are the WattWise NEC explainer.",
            "Explain the known NEC reference in plain English for electrician exam prep.",
            "Do not quote copyrighted NEC text.",
            "Do not invent other NEC references.",
            "Do not claim that all states use the 2026 NEC.",
            "If jurisdiction adoption is unknown, say adoption varies by jurisdiction.",
          ].join("\n"),
        },
        { role: "user", content: prompt },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`provider_http_${response.status}`);
  }

  const data = await response.json();
  return {
    model,
    latencyMs: Date.now() - startedAt,
    text: data.choices?.[0]?.message?.content ?? "",
    inputTokens: data.usage?.prompt_tokens ?? null,
    outputTokens: data.usage?.completion_tokens ?? null,
  };
}

function fallbackExplanation(entry: {
  reference_code: string;
  title: string;
  simplified_summary: string;
  topic_notes: string | null;
}) {
  const notes = normalizedText(entry.topic_notes);
  if (notes) return notes;

  return [
    `${entry.title} in NEC ${entry.reference_code} is about the installation decision described in the summary.`,
    entry.simplified_summary,
    "For exam prep, focus on what hazard, equipment condition, or design choice the section is trying to control.",
    "If a state-specific question depends on adoption or amendments, verify the official jurisdiction source before treating the rule as current there.",
  ].join(" ");
}

async function logAIRequest(
  supabase: ReturnType<typeof createClient>,
  {
    userId,
    necId,
    modelName,
    status,
    inputTokens,
    outputTokens,
    errorCode,
    errorMessage,
    latencyMs,
  }: {
    userId: string;
    necId: string | null;
    modelName: string | null;
    status: string;
    inputTokens?: number | null;
    outputTokens?: number | null;
    errorCode?: string | null;
    errorMessage?: string | null;
    latencyMs?: number | null;
  }
) {
  await supabase.from("ai_request_logs").insert({
    user_id: userId,
    request_type: "nec_explanation",
    related_nec_entry_id: necId,
    provider_name: providerName,
    model_name: modelName,
    model_used: modelName,
    status,
    prompt_version: promptVersion,
    prompt_tokens: inputTokens ?? null,
    completion_tokens: outputTokens ?? null,
    input_tokens: inputTokens ?? null,
    output_tokens: outputTokens ?? null,
    total_tokens: inputTokens != null && outputTokens != null ? inputTokens + outputTokens : null,
    error_code: errorCode ?? null,
    error_message: errorMessage ?? null,
    response_time_ms: latencyMs ?? null,
  });
}

async function logAppEvent(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  eventType: string,
  eventData: Record<string, unknown>,
  platform: string
) {
  await supabase.from("app_events").insert({
    user_id: userId,
    event_type: eventType,
    event_data: eventData,
    platform,
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ success: false, error: { message: "Method not allowed" } }, 405);
  }

  const platform = req.headers.get("X-Platform") ?? "unknown";
  const supabase = createClient(supabaseUrl, supabaseKey);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ success: false, error: { message: "Unauthorized" } }, 401);
    }

    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ success: false, error: { message: "Unauthorized" } }, 401);
    }

    const body = await req.json();
    const necId = normalizedText(body.nec_id);
    if (!necId) {
      return json({ success: false, error: { message: "Missing nec_id" } }, 400);
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
    const necExplanationsUsed = await countNECExplanations(supabase, user.id);
    const necExplanationLimit = hasPaidAccess ? -1 : 1;

    if (necExplanationLimit !== -1 && necExplanationsUsed >= necExplanationLimit) {
      await logAIRequest(supabase, {
        userId: user.id,
        necId,
        modelName: null,
        status: "rate_limited",
        errorCode: "nec_quota_reached",
        errorMessage: "Preview NEC explanation limit reached",
      });
      await logAppEvent(supabase, user.id, "nec_explain_quota_hit", { nec_id: necId }, platform);
      return json({ success: false, error: { message: "You've used your preview NEC explanation." } }, 429);
    }

    const { data: entry, error } = await supabase
      .from("nec_entries")
      .select("id, reference_code, title, simplified_summary, topic_notes")
      .eq("id", necId)
      .maybeSingle();

    if (error) throw error;
    if (!entry) {
      return json({ success: false, error: { message: "NEC entry not found" } }, 404);
    }

    let expanded = fallbackExplanation(entry);
    let modelName: string | null = "fallback";
    let latencyMs: number | null = null;
    let inputTokens: number | null = null;
    let outputTokens: number | null = null;

    if (openaiKey) {
      const prompt = [
        `Known NEC reference: ${entry.reference_code} - ${entry.title}`,
        `Simplified summary: ${entry.simplified_summary}`,
        `Additional notes: ${entry.topic_notes ?? "None"}`,
        "Write four short paragraphs that explain:",
        "1. What the section is generally about",
        "2. Why it matters in practical electrical work",
        "3. What students commonly confuse",
        "4. What to remember for exam prep",
      ].join("\n\n");

      try {
        const providerResult = await callProvider({ model: primaryModel, prompt });
        expanded = providerResult.text.trim() || expanded;
        modelName = providerResult.model;
        latencyMs = providerResult.latencyMs;
        inputTokens = providerResult.inputTokens;
        outputTokens = providerResult.outputTokens;
      } catch {
        const providerResult = await callProvider({ model: fallbackModel, prompt });
        expanded = providerResult.text.trim() || expanded;
        modelName = providerResult.model;
        latencyMs = providerResult.latencyMs;
        inputTokens = providerResult.inputTokens;
        outputTokens = providerResult.outputTokens;
      }
    }

    const usage = {
      used: necExplanationLimit === -1 ? necExplanationsUsed : necExplanationsUsed + 1,
      limit: necExplanationLimit,
    };

    await logAIRequest(supabase, {
      userId: user.id,
      necId,
      modelName,
      status: "success",
      inputTokens,
      outputTokens,
      latencyMs,
    });
    await logAppEvent(
      supabase,
      user.id,
      "nec_explain_success",
      { nec_id: necId, prompt_version: promptVersion },
      platform
    );

    return json({
      success: true,
      data: {
        expanded,
        usage,
      },
    });
  } catch (error) {
    console.error("nec_explain error:", error);
    return json(
      { success: false, error: { message: "Couldn't generate the explanation right now." } },
      500
    );
  }
});
