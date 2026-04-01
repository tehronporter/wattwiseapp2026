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

    const { query } = await req.json();
    const term = String(query ?? "").trim();
    if (term.length === 0) {
      return json({ success: true, data: { results: [] } });
    }

    const { data: results, error } = await supabase
      .from("nec_entries")
      .select("id, reference_code, title, simplified_summary")
      .or(
        `reference_code.ilike.%${term}%,title.ilike.%${term}%,simplified_summary.ilike.%${term}%`
      )
      .eq("is_active", true)
      .limit(10);

    if (error) throw error;

    return json({
      success: true,
      data: {
        results: (results ?? []).map((entry: any) => ({
          id: entry.id,
          code: entry.reference_code,
          title: entry.title,
          summary: entry.simplified_summary,
        })),
      },
    });
  } catch (error) {
    console.error("nec_search error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500
    );
  }
});
