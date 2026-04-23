import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ success: false, error: { message: "Method not allowed" } }, 405);
  }

  try {
    const supabase = createClient(supabaseUrl, supabaseKey);
    const authHeader = req.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "").trim() || "";

    let authedUserId: string | null = null;
    if (token) {
      const {
        data: { user },
      } = await supabase.auth.getUser(token);
      authedUserId = user?.id ?? null;
    }

    const {
      event_name,
      platform,
      properties,
      occurred_at,
      user_id,
      exam_type,
      state,
      device_id,
    } = await req.json();

    if (!event_name || typeof event_name !== "string") {
      return json({ success: false, error: { message: "Missing event_name" } }, 400);
    }

    const row = {
      event_name,
      platform: typeof platform === "string" && platform ? platform : "ios",
      user_id: authedUserId ?? user_id ?? null,
      exam_type: typeof exam_type === "string" && exam_type ? exam_type : null,
      jurisdiction_code: typeof state === "string" && state ? state : null,
      device_id: typeof device_id === "string" && device_id ? device_id : null,
      properties: properties && typeof properties === "object" ? properties : {},
      occurred_at: typeof occurred_at === "string" && occurred_at ? occurred_at : new Date().toISOString(),
    };

    const { error } = await supabase.from("client_events").insert(row);
    if (error) throw error;

    return json({ success: true, data: { recorded: true } });
  } catch (error) {
    console.error("track_client_event error:", error);
    return json({ success: false, error: { message: "Internal server error" } }, 500);
  }
});
