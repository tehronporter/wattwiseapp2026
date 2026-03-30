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

    const { nec_id } = await req.json();

    if (!nec_id) {
      return new Response(JSON.stringify({ error: "Missing nec_id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get NEC entry details
    const { data: entry, error: entryError } = await supabase
      .from("nec_entries")
      .select(
        `
        id,
        section,
        subsection,
        title,
        summary,
        full_text,
        year,
        topic_tags: nec_entry_topic_tags (
          topic_tags (tag)
        )
      `
      )
      .eq("id", nec_id)
      .single();

    if (entryError || !entry) {
      return new Response(JSON.stringify({ error: "NEC entry not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get related lesson references
    const { data: lessonRefs } = await supabase
      .from("lesson_nec_references")
      .select(
        `
        lessons (
          id,
          title,
          module_id,
          modules (title)
        )
      `
      )
      .eq("nec_id", nec_id)
      .limit(5);

    const topics = entry.topic_tags.map((t: any) => t.topic_tags.tag);
    const relatedLessons = (lessonRefs || []).map((ref: any) => ({
      lesson_id: ref.lessons.id,
      lesson_title: ref.lessons.title,
      module_title: ref.lessons.modules.title,
    }));

    return new Response(
      JSON.stringify({
        detail: {
          id: entry.id,
          section: entry.section,
          subsection: entry.subsection,
          title: entry.title,
          summary: entry.summary,
          full_text: entry.full_text,
          year: entry.year,
          topics,
          related_lessons: relatedLessons,
        },
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
