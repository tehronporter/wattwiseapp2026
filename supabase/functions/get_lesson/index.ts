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
    const { lesson_id } = await req.json();

    if (!lesson_id) {
      return new Response(JSON.stringify({ error: "Missing lesson_id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get lesson with sections and NEC references
    const { data: lesson, error: lessonError } = await supabase
      .from("lessons")
      .select(
        `
        id,
        title,
        description,
        difficulty_level,
        estimated_minutes,
        module_id,
        modules (title),
        lesson_sections (
          id,
          section_number,
          title,
          content,
          nec_references: lesson_nec_references (
            nec_entries (
              id,
              section,
              subsection,
              title
            )
          )
        ),
        topic_tags: lesson_topic_tags (
          topic_tags (tag)
        )
      `
      )
      .eq("id", lesson_id)
      .single();

    if (lessonError || !lesson) {
      return new Response(JSON.stringify({ error: "Lesson not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get user progress for this lesson
    const { data: progress } = await supabase
      .from("lesson_progress")
      .select("completion_percentage")
      .eq("user_id", userId)
      .eq("lesson_id", lesson_id)
      .single();

    // Transform NEC references
    const sections = lesson.lesson_sections.map((section: any) => ({
      id: section.id,
      section_number: section.section_number,
      title: section.title,
      content: section.content,
      nec_callouts: section.nec_references.map((ref: any) => ({
        id: ref.nec_entries.id,
        section: ref.nec_entries.section,
        subsection: ref.nec_entries.subsection,
        title: ref.nec_entries.title,
      })),
    }));

    const topics = lesson.topic_tags.map((t: any) => t.topic_tags.tag);

    return new Response(
      JSON.stringify({
        lesson: {
          id: lesson.id,
          title: lesson.title,
          description: lesson.description,
          difficulty_level: lesson.difficulty_level,
          estimated_minutes: lesson.estimated_minutes,
          module_title: lesson.modules.title,
          sections,
          topics,
          progress_percentage: progress?.completion_percentage || 0,
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
