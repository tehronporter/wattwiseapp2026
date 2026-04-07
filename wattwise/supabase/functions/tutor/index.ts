import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const openaiKey = Deno.env.get("OPENAI_API_KEY");
const primaryModel = Deno.env.get("AI_TUTOR_PRIMARY_MODEL") ?? "gpt-4o-mini";
const fallbackModel = Deno.env.get("AI_TUTOR_FALLBACK_MODEL") ?? "gpt-4.1-mini";
const promptVersion = "tutor_v2";
const providerName = "openai";

type TutorHistoryItem = {
  role?: string;
  content?: string;
};

type TutorContextPayload = {
  type?: string;
  id?: string | null;
  excerpt?: string | null;
  title?: string | null;
  topicTags?: string[];
  examType?: string | null;
  jurisdiction?: string | null;
  lesson?: {
    lessonId?: string;
    title?: string;
    excerpt?: string | null;
    topic?: string | null;
    necReferences?: string[];
  } | null;
  quizReview?: {
    quizId?: string;
    quizAttemptId?: string | null;
    score?: number;
    correctCount?: number;
    totalCount?: number;
    weakTopics?: string[];
    focusedQuestion?: {
      questionId?: string;
      question?: string;
      userAnswer?: string;
      correctAnswer?: string;
      explanation?: string;
      topics?: string[];
      referenceCode?: string | null;
    } | null;
  } | null;
  necDetail?: {
    necId?: string;
    code?: string;
    title?: string;
    summary?: string;
  } | null;
};

type TutorResponse = {
  answer: string;
  steps: string[];
  bullets: string[];
  references: string[];
  follow_ups: string[];
};

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

function normalizedList(value: unknown, limit = 6): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, limit);
}

function firstRelation<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) return value[0] ?? null;
  return value ?? null;
}

function explicitReferences(text: string): string[] {
  const matches = text.match(/\b(?:Article\s+)?\d{2,3}(?:\.\d+)?(?:\([A-Za-z0-9]+\))*\b/g) ?? [];
  return Array.from(new Set(matches.map((match) => match.replace(/^Article\s+/i, "Article ").trim())));
}

function allowedReferences(message: string, context: TutorContextPayload | null): string[] {
  const references = new Set<string>();

  for (const value of normalizedList(context?.lesson?.necReferences ?? [])) {
    references.add(value);
  }

  const quizReference = normalizedText(context?.quizReview?.focusedQuestion?.referenceCode);
  if (quizReference) references.add(quizReference);

  const necCode = normalizedText(context?.necDetail?.code);
  if (necCode) references.add(necCode);

  for (const value of explicitReferences(message)) {
    references.add(value);
  }

  return Array.from(references);
}

function trimmedConversation(history: TutorHistoryItem[]): { role: "user" | "assistant"; content: string }[] {
  return history
    .filter((item): item is { role: "user" | "assistant"; content: string } =>
      (item.role === "user" || item.role === "assistant") &&
      typeof item.content === "string" &&
      item.content.trim().length > 0
    )
    .slice(-6)
    .map((item) => ({
      role: item.role,
      content: item.content.trim(),
    }));
}

async function countTutorMessages(
  supabase: ReturnType<typeof createClient>,
  userId: string,
) {
  const { data: sessions, error: sessionsError } = await supabase
    .from("tutor_sessions")
    .select("id")
    .eq("user_id", userId);

  if (sessionsError) throw sessionsError;
  if (!sessions || sessions.length === 0) return 0;

  const { count, error } = await supabase
    .from("tutor_messages")
    .select("*", { count: "exact", head: true })
    .eq("role", "user")
    .in("session_id", sessions.map((session) => session.id));

  if (error) throw error;
  return count ?? 0;
}

async function createOrReuseSession(
  supabase: ReturnType<typeof createClient>,
  {
    userId,
    sessionId,
    context,
  }: {
    userId: string;
    sessionId: string | null;
    context: TutorContextPayload | null;
  }
) {
  if (sessionId) {
    const { data: existing } = await supabase
      .from("tutor_sessions")
      .select("id")
      .eq("id", sessionId)
      .eq("user_id", userId)
      .maybeSingle();

    if (existing?.id) {
      return existing.id as string;
    }
  }

  const sessionTitle = normalizedText(context?.title)
    ?? normalizedText(context?.lesson?.title)
    ?? normalizedText(context?.necDetail?.title)
    ?? "Tutor Session";

  const { data: created, error } = await supabase
    .from("tutor_sessions")
    .insert({
      user_id: userId,
      context_type: context?.type ?? "general",
      context_id: normalizedText(context?.id) ?? null,
      context_lesson_id: normalizedText(context?.lesson?.lessonId) ?? null,
      context_quiz_attempt_id: normalizedText(context?.quizReview?.quizAttemptId) ?? null,
      context_nec_entry_id: normalizedText(context?.necDetail?.necId) ?? null,
      title: sessionTitle,
      message_count: 0,
      last_message_at: new Date().toISOString(),
    })
    .select("id")
    .single();

  if (error || !created) throw error;
  return created.id as string;
}

async function persistTutorMessages(
  supabase: ReturnType<typeof createClient>,
  {
    sessionId,
    userMessage,
    assistantMessage,
    modelName,
    messageCount,
  }: {
    sessionId: string;
    userMessage: string;
    assistantMessage: TutorResponse;
    modelName: string;
    messageCount: number;
  }
) {
  const messageTime = new Date().toISOString();
  const { error: messageError } = await supabase.from("tutor_messages").insert([
    {
      session_id: sessionId,
      role: "user",
      content: userMessage,
      message_text: userMessage,
      meta_json: {},
      structured_json: null,
      created_at: messageTime,
    },
    {
      session_id: sessionId,
      role: "assistant",
      content: assistantMessage.answer,
      message_text: assistantMessage.answer,
      meta_json: {
        steps: assistantMessage.steps,
        bullets: assistantMessage.bullets,
        references: assistantMessage.references,
        follow_ups: assistantMessage.follow_ups,
      },
      structured_json: assistantMessage,
      model_name: modelName,
      created_at: messageTime,
    },
  ]);

  if (messageError) throw messageError;

  await supabase
    .from("tutor_sessions")
    .update({
      message_count: messageCount,
      updated_at: messageTime,
      last_message_at: messageTime,
    })
    .eq("id", sessionId);
}

async function logAIRequest(
  supabase: ReturnType<typeof createClient>,
  {
    userId,
    sessionId,
    modelName,
    status,
    inputTokens,
    outputTokens,
    errorCode,
    errorMessage,
    latencyMs,
    contextType,
  }: {
    userId: string;
    sessionId: string | null;
    modelName: string | null;
    status: string;
    inputTokens?: number | null;
    outputTokens?: number | null;
    errorCode?: string | null;
    errorMessage?: string | null;
    latencyMs?: number | null;
    contextType?: string | null;
  }
) {
  await supabase.from("ai_request_logs").insert({
    user_id: userId,
    request_type: "tutor",
    related_session_id: sessionId,
    provider_name: providerName,
    model_name: modelName,
    model_used: modelName,
    status,
    prompt_version: promptVersion,
    context_type: contextType,
    input_tokens: inputTokens ?? null,
    output_tokens: outputTokens ?? null,
    prompt_tokens: inputTokens ?? null,
    completion_tokens: outputTokens ?? null,
    total_tokens: inputTokens != null && outputTokens != null ? inputTokens + outputTokens : null,
    error_code: errorCode ?? null,
    error_message: errorMessage ?? null,
    response_time_ms: latencyMs ?? null,
  });
}

async function logAppEvent(
  supabase: ReturnType<typeof createClient>,
  {
    userId,
    eventType,
    eventData,
    platform,
  }: {
    userId: string;
    eventType: string;
    eventData: Record<string, unknown>;
    platform: string;
  }
) {
  await supabase.from("app_events").insert({
    user_id: userId,
    event_type: eventType,
    event_data: eventData,
    platform,
  });
}

async function hydrateContext(
  supabase: ReturnType<typeof createClient>,
  context: TutorContextPayload | null
) {
  if (!context) return null;

  const hydrated: TutorContextPayload = {
    ...context,
    topicTags: normalizedList(context.topicTags ?? []),
  };

  if (context.type === "lesson" && !hydrated.lesson?.title) {
    const lessonId = normalizedText(context.lesson?.lessonId) ?? normalizedText(context.id);
    if (lessonId) {
      const { data: lesson } = await supabase
        .from("lessons")
        .select("id, title, summary")
        .eq("id", lessonId)
        .maybeSingle();

      if (lesson) {
        hydrated.lesson = {
          lessonId: lesson.id,
          title: lesson.title,
          excerpt: lesson.summary,
          topic: hydrated.lesson?.topic ?? null,
          necReferences: normalizedList(hydrated.lesson?.necReferences ?? []),
        };
      }
    }
  }

  if (context.type === "nec_detail" && !hydrated.necDetail?.title) {
    const necId = normalizedText(context.necDetail?.necId) ?? normalizedText(context.id);
    if (necId) {
      const { data: necEntry } = await supabase
        .from("nec_entries")
        .select("id, reference_code, title, simplified_summary")
        .eq("id", necId)
        .maybeSingle();

      if (necEntry) {
        hydrated.necDetail = {
          necId: necEntry.id,
          code: necEntry.reference_code,
          title: necEntry.title,
          summary: necEntry.simplified_summary,
        };
      }
    }
  }

  return hydrated;
}

function buildContextSummary(context: TutorContextPayload | null) {
  if (!context) return "No structured source context attached.";

  const shared = {
    mode: context.type ?? "general",
    exam_type: normalizedText(context.examType) ?? "unspecified",
    jurisdiction: normalizedText(context.jurisdiction) ?? "unspecified",
    topic_tags: normalizedList(context.topicTags ?? []),
  };

  if (context.type === "lesson") {
    return JSON.stringify({
      ...shared,
      lesson_title: normalizedText(context.lesson?.title) ?? normalizedText(context.title),
      lesson_excerpt: normalizedText(context.lesson?.excerpt) ?? normalizedText(context.excerpt),
      lesson_topic: normalizedText(context.lesson?.topic),
      related_nec_references: normalizedList(context.lesson?.necReferences ?? []),
    }, null, 2);
  }

  if (context.type === "quiz_review") {
    return JSON.stringify({
      ...shared,
      score: context.quizReview?.score ?? null,
      correct_count: context.quizReview?.correctCount ?? null,
      total_count: context.quizReview?.totalCount ?? null,
      weak_topics: normalizedList(context.quizReview?.weakTopics ?? []),
      focused_question: context.quizReview?.focusedQuestion ?? null,
    }, null, 2);
  }

  if (context.type === "nec_detail") {
    return JSON.stringify({
      ...shared,
      nec_code: normalizedText(context.necDetail?.code),
      nec_title: normalizedText(context.necDetail?.title),
      nec_summary: normalizedText(context.necDetail?.summary) ?? normalizedText(context.excerpt),
    }, null, 2);
  }

  return JSON.stringify(shared, null, 2);
}

async function callProvider({
  systemPrompt,
  message,
  history,
  model,
}: {
  systemPrompt: string;
  message: string;
  history: { role: "user" | "assistant"; content: string }[];
  model: string;
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
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        ...history.map((item) => ({ role: item.role, content: item.content })),
        { role: "user", content: message },
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

function parseTutorResponse(rawText: string, allowedRefs: string[]): TutorResponse {
  const trimmed = rawText.trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  const jsonText = start >= 0 && end >= start ? trimmed.slice(start, end + 1) : trimmed;
  const parsed = JSON.parse(jsonText);

  const answer = normalizedText(parsed.answer);
  if (!answer) {
    throw new Error("invalid_tutor_answer");
  }

  const allowedSet = new Set(allowedRefs.map((value) => value.toLowerCase()));
  const references = normalizedList(parsed.references ?? [])
    .filter((value) => allowedSet.size === 0 || allowedSet.has(value.toLowerCase()))
    .slice(0, 4);

  return {
    answer,
    steps: normalizedList(parsed.steps ?? [], 4),
    bullets: normalizedList(parsed.bullets ?? [], 4),
    references,
    follow_ups: normalizedList(parsed.follow_ups ?? [], 4),
  };
}

function fallbackTutorResponse(
  message: string,
  context: TutorContextPayload | null,
  references: string[]
): TutorResponse {
  const focus = context?.type === "lesson"
    ? "this lesson"
    : context?.type === "quiz_review"
      ? "this quiz result"
      : context?.type === "nec_detail"
        ? "this NEC reference"
        : "that topic";

  return {
    answer: `I'm not certain enough to give a fuller AI answer right now, but I can still help you study ${focus}. Start by identifying the main concept, the practical decision it affects, and the exact wording that the exam question is testing.`,
    steps: [
      "Name the core concept in plain English before you reach for code language.",
      "Decide what installation rule, calculation, or safety decision the question is really asking about.",
      "Verify any jurisdiction-specific adoption or amendment with the official state or AHJ source before treating it as current.",
    ],
    bullets: [
      "Use the explanation already shown in WattWise as your anchor.",
      "Slow down on words that change scope, occupancy, or equipment type.",
    ],
    references: references.slice(0, 2),
    follow_ups: [
      "Explain this more simply",
      "What should I remember for the exam?",
      "Give me a similar practice example",
    ],
  };
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
    const message = normalizedText(body.message);
    const sessionId = normalizedText(body.session_id);
    const history = trimmedConversation(Array.isArray(body.history) ? body.history : []);
    const rawContext = (typeof body.context === "object" && body.context !== null)
      ? body.context as TutorContextPayload
      : null;

    if (!message) {
      return json({ success: false, error: { message: "Missing message" } }, 400);
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
    const tutorMessagesUsed = await countTutorMessages(supabase, user.id);
    const tutorMessagesLimit = hasPaidAccess ? -1 : 4;

    if (tutorMessagesLimit !== -1 && tutorMessagesUsed >= tutorMessagesLimit) {
      await logAIRequest(supabase, {
        userId: user.id,
        sessionId,
        modelName: null,
        status: "rate_limited",
        errorCode: "tutor_quota_reached",
        errorMessage: "Preview tutor limit reached",
        contextType: rawContext?.type ?? "general",
      });
      await logAppEvent(supabase, {
        userId: user.id,
        eventType: "tutor_quota_hit",
        eventData: { context_type: rawContext?.type ?? "general" },
        platform,
      });
      return json({ success: false, error: { message: "You've used your preview tutor questions." } }, 429);
    }

    const context = await hydrateContext(supabase, rawContext);
    const references = allowedReferences(message, context);
    const session = await createOrReuseSession(supabase, {
      userId: user.id,
      sessionId,
      context,
    });

    const contextSummary = buildContextSummary(context);
    const systemPrompt = [
      "You are the WattWise AI Tutor, a calm and precise electrician exam study guide.",
      "Educational first, not chat-first.",
      "Teach clearly before using jargon.",
      "Use step-by-step reasoning when it helps the learner.",
      "Tie explanations to field practice and exam thinking.",
      "Do not quote copyrighted NEC text.",
      "Do not invent NEC references. Only use references from the allowed list.",
      "If you are not certain, say 'I'm not certain' and explain what would need to be verified.",
      "Do not claim that all states use the 2026 NEC. Adoption varies by jurisdiction and official state sources must control.",
      "If jurisdiction-specific adoption is not provided, say that state adoption varies and recommend checking the official board, AHJ, or state code source.",
      "Keep the default answer concise and helpful.",
      "Return JSON only with this exact shape: {\"answer\":\"string\",\"steps\":[\"string\"],\"bullets\":[\"string\"],\"references\":[\"string\"],\"follow_ups\":[\"string\"]}.",
      `Allowed NEC references: ${references.length > 0 ? references.join(", ") : "none supplied"}.`,
      `Prompt version: ${promptVersion}.`,
    ].join("\n");

    const userPrompt = [
      `Current learner message:\n${message}`,
      `Structured context:\n${contextSummary}`,
      "Response requirements:",
      "- answer: one short teaching paragraph",
      "- steps: include only when a sequence really helps",
      "- bullets: include only high-value reminders or distinctions",
      "- references: only from the allowed list",
      "- follow_ups: 2 to 4 useful next prompts",
    ].join("\n\n");

    let providerResult:
      | {
          model: string;
          latencyMs: number;
          text: string;
          inputTokens: number | null;
          outputTokens: number | null;
        }
      | null = null;
    let structuredResponse: TutorResponse;
    try {
      providerResult = await callProvider({
        systemPrompt,
        message: userPrompt,
        history,
        model: primaryModel,
      });
      structuredResponse = parseTutorResponse(providerResult.text, references);
    } catch {
      try {
        providerResult = await callProvider({
          systemPrompt,
          message: userPrompt,
          history,
          model: fallbackModel,
        });
        structuredResponse = parseTutorResponse(providerResult.text, references);
      } catch {
        providerResult = {
          model: "fallback_local",
          latencyMs: 0,
          text: "",
          inputTokens: null,
          outputTokens: null,
        };
        structuredResponse = fallbackTutorResponse(message, context, references);
      }
    }
    await persistTutorMessages(supabase, {
      sessionId: session,
      userMessage: message,
      assistantMessage: structuredResponse,
      modelName: providerResult.model,
      messageCount: history.length + 2,
    });

    const usage = {
      used: tutorMessagesLimit === -1 ? tutorMessagesUsed : tutorMessagesUsed + 1,
      limit: tutorMessagesLimit,
    };

    await logAIRequest(supabase, {
      userId: user.id,
      sessionId: session,
      modelName: providerResult.model,
      status: "success",
      inputTokens: providerResult.inputTokens,
      outputTokens: providerResult.outputTokens,
      latencyMs: providerResult.latencyMs,
      contextType: context?.type ?? "general",
    });

    await logAppEvent(supabase, {
      userId: user.id,
      eventType: "tutor_response_success",
      eventData: {
        context_type: context?.type ?? "general",
        session_id: session,
        prompt_version: promptVersion,
      },
      platform,
    });

    return json({
      success: true,
      data: {
        ...structuredResponse,
        session_id: session,
        usage,
      },
    });
  } catch (error) {
    console.error("tutor error:", error);

    const authHeader = req.headers.get("Authorization");
    if (authHeader) {
      const token = authHeader.replace("Bearer ", "");
      const {
        data: { user },
      } = await supabase.auth.getUser(token);
      if (user) {
        await logAIRequest(supabase, {
          userId: user.id,
          sessionId: null,
          modelName: null,
          status: "error",
          errorCode: "tutor_internal_error",
          errorMessage: error instanceof Error ? error.message : "Unknown tutor error",
          contextType: null,
        });
      }
    }

    return json(
      { success: false, error: { message: "Tutor unavailable right now. Please try again." } },
      500
    );
  }
});
