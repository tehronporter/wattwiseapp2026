import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Resolve the NEC edition to filter by, in priority order:
//   1. explicit edition_override from client
//   2. state code lookup in jurisdiction_nec_editions
//   3. fall back to '2023'
async function resolveEdition(
  supabase: ReturnType<typeof createClient>,
  stateCode?: string,
  editionOverride?: string
): Promise<string> {
  const validEditions = ["2017", "2020", "2023", "2026"];

  if (editionOverride && validEditions.includes(editionOverride)) {
    return editionOverride;
  }

  if (stateCode && stateCode.length === 2) {
    const { data } = await supabase
      .from("jurisdiction_nec_editions")
      .select("adopted_edition")
      .eq("jurisdiction_code", stateCode.toUpperCase())
      .maybeSingle();

    if (data?.adopted_edition && validEditions.includes(data.adopted_edition)) {
      return data.adopted_edition;
    }
  }

  return "2023";
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

    const { query, state_code, edition_override } = await req.json();
    const term = String(query ?? "").trim();
    if (term.length === 0) {
      return json({ success: true, data: { results: [], edition: "2023" } });
    }

    const edition = await resolveEdition(supabase, state_code, edition_override);

    // Build query — filter by edition when nec_edition column is populated,
    // but also include rows where nec_edition is null (legacy rows without edition tag).
    const { data: results, error } = await supabase
      .from("nec_entries")
      .select("id, reference_code, title, simplified_summary, nec_edition")
      .or(
        `reference_code.ilike.%${term}%,title.ilike.%${term}%,simplified_summary.ilike.%${term}%`
      )
      .eq("is_active", true)
      .or(`nec_edition.eq.${edition},nec_edition.is.null`)
      .limit(10);

    if (error) throw error;

    return json({
      success: true,
      data: {
        edition,
        results: (results ?? []).map((entry: any) => ({
          id: entry.id,
          code: entry.reference_code,
          title: entry.title,
          summary: entry.simplified_summary,
          edition: entry.nec_edition ?? edition,
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
