import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function firstRelation<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) {
    return value[0] ?? null;
  }
  return value ?? null;
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

    const { lesson_id } = await req.json();
    if (!lesson_id) {
      return json({ success: false, error: { message: "Missing lesson_id" } }, 400);
    }

    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("tier, status, expires_at")
      .eq("user_id", user.id)
      .maybeSingle();

    const hasPaidAccess = (
      (subscription?.tier === "fast_track" || subscription?.tier === "full_prep") &&
      subscription?.status === "active" &&
      (!subscription?.expires_at || new Date(subscription.expires_at).getTime() > Date.now())
    );

    if (!hasPaidAccess) {
      const { data: firstModule, error: moduleError } = await supabase
        .from("modules")
        .select("id")
        .eq("is_published", true)
        .order("sort_order", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (moduleError) throw moduleError;

      if (firstModule) {
        const { data: previewLesson, error: previewLessonError } = await supabase
          .from("lessons")
          .select("id")
          .eq("is_published", true)
          .eq("module_id", firstModule.id)
          .order("sort_order", { ascending: true })
          .limit(1)
          .maybeSingle();

        if (previewLessonError) throw previewLessonError;

        if (previewLesson && previewLesson.id !== lesson_id) {
          return json(
            { success: false, error: { message: "Preview includes your first full lesson. Choose full access to keep going." } },
            403,
          );
        }
      }
    }

    const { data: lesson, error: lessonError } = await supabase
      .from("lessons")
      .select(`
        id,
        module_id,
        title,
        estimated_minutes,
        is_published,
        modules (
          title
        )
      `)
      .eq("id", lesson_id)
      .maybeSingle();

    if (lessonError) throw lessonError;
    if (!lesson || lesson.is_published === false) {
      return json({ success: false, error: { message: "Lesson not found" } }, 404);
    }

    const { data: sectionRows, error: sectionsError } = await supabase
      .from("lesson_sections")
      .select("id, sort_order, section_type, heading, body_plaintext, body_markdown, meta_json")
      .eq("lesson_id", lesson_id)
      .order("sort_order", { ascending: true });

    if (sectionsError) throw sectionsError;

    const { data: necRows, error: necError } = await supabase
      .from("lesson_nec_references")
      .select(`
        display_order,
        nec_entries (
          id,
          reference_code,
          title,
          simplified_summary,
          topic_notes
        )
      `)
      .eq("lesson_id", lesson_id)
      .order("display_order", { ascending: true });

    if (necError) throw necError;

    const { data: progressRow, error: progressError } = await supabase
      .from("lesson_progress")
      .select("status, completion_percentage")
      .eq("user_id", user.id)
      .eq("lesson_id", lesson_id)
      .maybeSingle();

    if (progressError) throw progressError;

    const sections = (sectionRows ?? []).map((section: any) => ({
      id: section.id,
      heading: section.heading,
      body: section.body_plaintext ?? section.body_markdown ?? "",
      type: section.section_type,
      necCode: section.meta_json?.necReferences?.[0] ?? null,
    }));

    const necReferences = (necRows ?? [])
      .map((row: any) => firstRelation(row.nec_entries))
      .filter(Boolean)
      .map((entry: any) => ({
        id: entry.id,
        code: entry.reference_code,
        title: entry.title,
        summary: entry.simplified_summary,
        expanded: entry.topic_notes ?? null,
      }));

    const completion = progressRow
      ? Number(progressRow.completion_percentage) / 100
      : 0;

    const moduleRecord = firstRelation(lesson.modules);

    return json({
      success: true,
      data: {
        lesson: {
          id: lesson.id,
          moduleId: lesson.module_id,
          title: lesson.title,
          topic: moduleRecord?.title ?? "Lesson",
          estimatedMinutes: lesson.estimated_minutes ?? 15,
          status: progressRow?.status ?? "not_started",
          completionPercentage: completion,
          sections,
          necReferences,
        },
      },
    });
  } catch (error) {
    console.error("get_lesson error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500
    );
  }
});
