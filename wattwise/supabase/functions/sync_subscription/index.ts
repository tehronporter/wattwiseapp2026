import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

async function countForUser(supabase: ReturnType<typeof createClient>, table: string, userId: string, filters: Record<string, string> = {}) {
  let query = supabase.from(table).select("*", { count: "exact", head: true }).eq("user_id", userId);
  for (const [key, value] of Object.entries(filters)) query = query.eq(key, value);
  const { count, error } = await query;
  if (error) throw error;
  return count ?? 0;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ success: false, error: { message: "Method not allowed" } }, 405);
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ success: false, error: { message: "Unauthorized" } }, 401);
    const supabase = createClient(supabaseUrl, supabaseKey);
    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (authError || !user) return json({ success: false, error: { message: "Unauthorized" } }, 401);

    // Entitlements are written only by trusted provider verification paths.
    // Client-supplied product IDs, transaction IDs, dates, and receipts are ignored.
    let { data: subscription, error } = await supabase.from("subscriptions").select("tier, status, expires_at, store_product_id").eq("user_id", user.id).maybeSingle();
    if (error) throw error;
    if (!subscription) {
      const created = await supabase.from("subscriptions").insert({ user_id: user.id, tier: "preview", status: "active" }).select("tier, status, expires_at, store_product_id").single();
      if (created.error) throw created.error;
      subscription = created.data;
    }

    const validPaidTier = subscription.tier === "fast_track" || subscription.tier === "full_prep";
    const active = subscription.status === "active" && (!subscription.expires_at || new Date(subscription.expires_at).getTime() > Date.now());
    const hasPaidAccess = validPaidTier && active;
    const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString();
    const previewQuizzesUsed = await countForUser(supabase, "quiz_attempts", user.id);
    const necExplanationsUsed = await countForUser(supabase, "ai_request_logs", user.id, { request_type: "nec_explanation", status: "success" });
    const { data: sessions } = await supabase.from("tutor_sessions").select("id").eq("user_id", user.id);
    let tutorMessagesUsed = 0;
    if (sessions?.length) {
      const result = await supabase.from("tutor_messages").select("*", { count: "exact", head: true }).eq("role", "user").gte("created_at", monthStart).in("session_id", sessions.map((item) => item.id));
      if (result.error) throw result.error;
      tutorMessagesUsed = result.count ?? 0;
    }

    return json({ success: true, data: {
      tier: hasPaidAccess ? subscription.tier : "preview",
      status: hasPaidAccess ? "active" : subscription.status,
      expires_at: subscription.expires_at,
      store_product_id: subscription.store_product_id,
      preview_quizzes_used: previewQuizzesUsed,
      preview_quizzes_limit: hasPaidAccess ? -1 : 1,
      tutor_messages_used: tutorMessagesUsed,
      tutor_messages_limit: hasPaidAccess ? 200 : 4,
      nec_explanations_used: necExplanationsUsed,
      nec_explanations_limit: hasPaidAccess ? 50 : 1,
    } });
  } catch (error) {
    console.error(JSON.stringify({ event: "sync_subscription_failed", message: error instanceof Error ? error.message : "unknown" }));
    return json({ success: false, error: { message: "Internal server error" } }, 500);
  }
});
