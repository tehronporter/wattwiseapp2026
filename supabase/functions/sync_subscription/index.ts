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
    const { receipt } = await req.json();

    // Check existing subscription
    const { data: existing } = await supabase
      .from("subscriptions")
      .select("id, tier, status, expires_at")
      .eq("user_id", userId)
      .single();

    let tier = "free";
    let status = "inactive";
    let expiresAt = null;

    // If receipt provided, validate it (simplified - would use Apple/Google validation in production)
    if (receipt) {
      // In production: validate receipt with Apple/Google API
      // For now: treat receipt as valid and upgrade to pro
      tier = "pro";
      status = "active";

      // Set expiration (30 days for monthly, 365 for yearly)
      const expirationDate = new Date();
      expirationDate.setDate(expirationDate.getDate() + 30); // Assume monthly for demo
      expiresAt = expirationDate.toISOString();

      // Record purchase
      await supabase.from("purchase_receipts").insert({
        user_id: userId,
        receipt,
        product_id: "wattwise.pro.monthly",
        purchase_date: new Date().toISOString(),
        expires_at: expiresAt,
      });

      // Upsert subscription
      await supabase.from("subscriptions").upsert(
        {
          user_id: userId,
          tier,
          status,
          expires_at: expiresAt,
        },
        { onConflict: "user_id" }
      );
    } else if (existing) {
      // Check if existing subscription is still valid
      tier = existing.tier;
      status = existing.status;
      expiresAt = existing.expires_at;

      if (
        expiresAt &&
        new Date(expiresAt) < new Date()
      ) {
        tier = "free";
        status = "expired";

        // Update to free tier
        await supabase
          .from("subscriptions")
          .update({ tier: "free", status: "expired" })
          .eq("user_id", userId);
      }
    } else {
      // First time - create free tier record
      await supabase.from("subscriptions").insert({
        user_id: userId,
        tier: "free",
        status: "active",
      });
    }

    return new Response(
      JSON.stringify({
        tier,
        status,
        expires_at: expiresAt,
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
