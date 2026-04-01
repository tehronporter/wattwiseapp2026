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

    const { data: modules, error: modulesError } = await supabase
      .from("modules")
      .select(`
        id,
        title,
        description,
        estimated_minutes,
        sort_order,
        module_topic_tags (
          topic_tags (
            slug
          )
        )
      `)
      .eq("is_published", true)
      .order("sort_order", { ascending: true });

    if (modulesError) throw modulesError;

    const { data: lessons, error: lessonsError } = await supabase
      .from("lessons")
      .select(`
        id,
        module_id,
        title,
        estimated_minutes,
        sort_order
      `)
      .eq("is_published", true)
      .order("sort_order", { ascending: true });

    if (lessonsError) throw lessonsError;

    const lessonIds = (lessons ?? []).map((lesson: any) => lesson.id);
    const { data: progressRows, error: progressError } = lessonIds.length === 0
      ? { data: [], error: null }
      : await supabase
          .from("lesson_progress")
          .select("lesson_id, status, completion_percentage")
          .eq("user_id", user.id)
          .in("lesson_id", lessonIds);

    if (progressError) throw progressError;

    const progressByLesson = new Map(
      (progressRows ?? []).map((row: any) => [row.lesson_id, row])
    );

    const lessonsByModule = new Map<string, any[]>();
    for (const lesson of lessons ?? []) {
      const lessonProgress = progressByLesson.get(lesson.id);
      const completion = lessonProgress
        ? Number(lessonProgress.completion_percentage) / 100
        : 0;

      const lessonPayload = {
        id: lesson.id,
        moduleId: lesson.module_id,
        title: lesson.title,
        topic: (modules ?? []).find((module: any) => module.id === lesson.module_id)?.title ?? "Lesson",
        estimatedMinutes: lesson.estimated_minutes ?? 15,
        status: lessonProgress?.status ?? "not_started",
        completionPercentage: completion,
        sections: [],
        necReferences: [],
      };

      if (!lessonsByModule.has(lesson.module_id)) {
        lessonsByModule.set(lesson.module_id, []);
      }
      lessonsByModule.get(lesson.module_id)!.push(lessonPayload);
    }

    const modulePayload = (modules ?? []).map((module: any) => {
      const moduleLessons = lessonsByModule.get(module.id) ?? [];
      const averageProgress =
        moduleLessons.length === 0
          ? 0
          : moduleLessons.reduce(
              (sum: number, lesson: any) => sum + lesson.completionPercentage,
              0
            ) / moduleLessons.length;

      return {
        id: module.id,
        title: module.title,
        description: module.description ?? "",
        lessonCount: moduleLessons.length,
        estimatedMinutes:
          module.estimated_minutes ??
          moduleLessons.reduce(
            (sum: number, lesson: any) => sum + lesson.estimatedMinutes,
            0
          ),
        topicTags: (module.module_topic_tags ?? []).map(
          (entry: any) => entry.topic_tags?.slug
        ).filter(Boolean),
        progress: averageProgress,
        lessons: moduleLessons,
      };
    });

    return json({
      success: true,
      data: {
        modules: modulePayload,
      },
    });
  } catch (error) {
    console.error("get_modules error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500
    );
  }
});
