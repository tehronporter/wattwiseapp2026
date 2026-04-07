import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const previewQuickQuizLimit = 1;
const previewTutorLimit = 4;
const previewNECLimit = 1;

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

function tierForProduct(productId: string | null): "fast_track" | "full_prep" | null {
  switch (productId) {
    case "wattwise.fasttrack.3month":
      return "fast_track";
    case "wattwise.fullprep.12month":
      return "full_prep";
    default:
      return null;
  }
}

function defaultExpiryForProduct(productId: string, purchaseDate: Date): Date {
  const months = productId === "wattwise.fasttrack.3month" ? 3 : 12;
  const expiresAt = new Date(purchaseDate);
  expiresAt.setMonth(expiresAt.getMonth() + months);
  return expiresAt;
}

function isActivePaidAccess(tier: string | null, status: string | null, expiresAt: string | null) {
  if (tier !== "fast_track" && tier !== "full_prep") return false;
  if (status !== "active") return false;
  if (!expiresAt) return true;
  return new Date(expiresAt).getTime() > Date.now();
}

async function countPreviewQuizAttempts(
  supabase: ReturnType<typeof createClient>,
  userId: string,
) {
  const { count, error } = await supabase
    .from("quiz_attempts")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId);

  if (error) throw error;
  return count ?? 0;
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
    const receipt = normalizedText(body.receipt);
    const productId = normalizedText(body.product_id);
    const transactionId = normalizedText(body.transaction_id);
    const originalTransactionId = normalizedText(body.original_transaction_id);
    const purchaseDateString = normalizedText(body.purchase_date);
    const expiresAtString = normalizedText(body.expires_at);

    const { data: existing, error: existingError } = await supabase
      .from("subscriptions")
      .select("id, tier, status, expires_at, store_product_id")
      .eq("user_id", user.id)
      .maybeSingle();

    if (existingError) throw existingError;

    let tier = existing?.tier ?? "preview";
    let status = existing?.status ?? "active";
    let expiresAt = existing?.expires_at ?? null;
    let storeProductId = existing?.store_product_id ?? null;

    const resolvedTier = tierForProduct(productId);
    if (resolvedTier && productId) {
      const purchaseDate = purchaseDateString ? new Date(purchaseDateString) : new Date();
      const resolvedExpiry = expiresAtString
        ? new Date(expiresAtString)
        : defaultExpiryForProduct(productId, purchaseDate);

      tier = resolvedTier;
      status = resolvedExpiry.getTime() > Date.now() ? "active" : "expired";
      expiresAt = resolvedExpiry.toISOString();
      storeProductId = productId;

      await supabase.from("purchase_receipts").insert({
        user_id: user.id,
        product_id: productId,
        receipt_data: receipt ?? JSON.stringify({
          product_id: productId,
          transaction_id: transactionId,
          original_transaction_id: originalTransactionId,
        }),
        transaction_id: transactionId,
        original_transaction_id: originalTransactionId,
        expires_at: resolvedExpiry.toISOString(),
        platform: "ios",
      });

      await supabase.from("subscriptions").upsert(
        {
          user_id: user.id,
          tier,
          status,
          expires_at: expiresAt,
          store_product_id: storeProductId,
          store_transaction_id: transactionId,
          store_original_transaction_id: originalTransactionId,
          last_verified_at: new Date().toISOString(),
        },
        { onConflict: "user_id" },
      );
    } else if (!existing) {
      await supabase.from("subscriptions").insert({
        user_id: user.id,
        tier: "preview",
        status: "active",
      });
      tier = "preview";
      status = "active";
      expiresAt = null;
      storeProductId = null;
    } else if (!isActivePaidAccess(existing.tier, existing.status, existing.expires_at)) {
      if (existing.tier !== "preview") {
        await supabase
          .from("subscriptions")
          .update({
            tier: "preview",
            status: "expired",
            expires_at: null,
            last_verified_at: new Date().toISOString(),
          })
          .eq("user_id", user.id);
        tier = "preview";
        status = "expired";
        expiresAt = null;
        storeProductId = existing.store_product_id ?? storeProductId;
      }
    }

    const previewQuizzesUsed = await countPreviewQuizAttempts(supabase, user.id);
    const tutorMessagesUsed = await countTutorMessages(supabase, user.id);
    const necExplanationsUsed = await countNECExplanations(supabase, user.id);

    const hasPaidAccess = tier === "fast_track" || tier === "full_prep";

    return json({
      success: true,
      data: {
        tier,
        status,
        expires_at: expiresAt,
        store_product_id: storeProductId,
        preview_quizzes_used: previewQuizzesUsed,
        preview_quizzes_limit: hasPaidAccess ? -1 : previewQuickQuizLimit,
        tutor_messages_used: tutorMessagesUsed,
        tutor_messages_limit: hasPaidAccess ? -1 : previewTutorLimit,
        nec_explanations_used: necExplanationsUsed,
        nec_explanations_limit: hasPaidAccess ? -1 : previewNECLimit,
      },
    });
  } catch (error) {
    console.error("sync_subscription error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500,
    );
  }
});
