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

    // Get all modules
    const { data: modules, error: modulesError } = await supabase
      .from("modules")
      .select(
        `
        id,
        title,
        description,
        icon,
        order,
        lessons (
          id,
          title
        )
      `
      )
      .order("order", { ascending: true });

    if (modulesError) throw modulesError;

    // For each module, get user progress
    const enrichedModules = await Promise.all(
      (modules || []).map(async (mod: any) => {
        const { data: progress } = await supabase
          .from("lesson_progress")
          .select("completion_percentage")
          .eq("user_id", userId)
          .in(
            "lesson_id",
            mod.lessons.map((l: any) => l.id)
          );

        const totalLessons = mod.lessons.length;
        const completedLessons =
          progress?.filter((p: any) => p.completion_percentage >= 100).length ||
          0;
        const progress_percentage =
          totalLessons > 0
            ? Math.round((completedLessons / totalLessons) * 100)
            : 0;

        return {
          id: mod.id,
          title: mod.title,
          description: mod.description,
          icon: mod.icon,
          lesson_count: totalLessons,
          completed_lessons: completedLessons,
          progress_percentage,
        };
      })
    );

    return new Response(
      JSON.stringify({
        modules: enrichedModules,
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
