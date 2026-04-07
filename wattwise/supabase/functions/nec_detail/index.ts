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

    const { data: entry, error } = await supabase
      .from("nec_entries")
      .select("id, reference_code, title, simplified_summary, topic_notes, nec_edition")
      .eq("id", nec_id)
      .maybeSingle();

    if (error) throw error;
    if (!entry) {
      return json({ success: false, error: { message: "NEC entry not found" } }, 404);
    }

    return json({
      success: true,
      data: {
        detail: {
          id: entry.id,
          code: entry.reference_code,
          title: entry.title,
          summary: entry.simplified_summary,
          expanded: entry.topic_notes ?? null,
          edition: entry.nec_edition ?? null,
        },
      },
    });
  } catch (error) {
    console.error("nec_detail error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500
    );
  }
});
