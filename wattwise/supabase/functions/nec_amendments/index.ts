import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

// Returns state-specific NEC amendments for a given NEC article and jurisdiction.
// Called from the NEC detail view when the user has a state set in their profile.

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

    const { nec_article, jurisdiction_code } = await req.json();

    if (!nec_article || !jurisdiction_code) {
      return json({ success: false, error: { message: "Missing nec_article or jurisdiction_code" } }, 400);
    }

    const { data: amendments, error } = await supabase
      .from("nec_state_amendments")
      .select("id, amendment_type, summary, effective_date, source_reference")
      .eq("jurisdiction_code", jurisdiction_code.toUpperCase())
      .eq("nec_article", nec_article)
      .eq("is_active", true)
      .order("effective_date", { ascending: false });

    if (error) throw error;

    // Also fetch the jurisdiction's adopted edition for context
    const { data: jurisdiction } = await supabase
      .from("jurisdiction_nec_editions")
      .select("adopted_edition, adoption_notes")
      .eq("jurisdiction_code", jurisdiction_code.toUpperCase())
      .maybeSingle();

    return json({
      success: true,
      data: {
        jurisdiction_code: jurisdiction_code.toUpperCase(),
        adopted_edition: jurisdiction?.adopted_edition ?? "2023",
        adoption_notes: jurisdiction?.adoption_notes ?? null,
        amendments: (amendments ?? []).map((a: any) => ({
          id: a.id,
          type: a.amendment_type,
          summary: a.summary,
          effectiveDate: a.effective_date,
          source: a.source_reference,
        })),
      },
    });
  } catch (error) {
    console.error("nec_amendments error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500
    );
  }
});
