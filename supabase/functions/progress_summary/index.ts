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

    // Get continue learning (most recently accessed incomplete lesson)
    const { data: continueLessons } = await supabase
      .from("lesson_progress")
      .select(
        `
        lesson_id,
        lessons (
          id,
          title,
          module_id,
          modules (title)
        ),
        completion_percentage
      `
      )
      .eq("user_id", userId)
      .lt("completion_percentage", 100)
      .order("updated_at", { ascending: false })
      .limit(1);

    const continueLearning =
      continueLessons && continueLessons.length > 0
        ? {
            lesson_id: continueLessons[0].lesson_id,
            title: continueLessons[0].lessons.title,
            progress: continueLessons[0].completion_percentage,
            module_title: continueLessons[0].lessons.modules.title,
          }
        : null;

    // Get today's study goal progress
    const today = new Date().toISOString().split("T")[0];
    const { data: dailyGoal } = await supabase
      .from("daily_study_goals")
      .select("minutes_completed, target_minutes")
      .eq("user_id", userId)
      .eq("goal_date", today)
      .single();

    // Get streak
    const { data: profile } = await supabase
      .from("profiles")
      .select("streak_days")
      .eq("id", userId)
      .single();

    return new Response(
      JSON.stringify({
        continue_learning: continueLearning,
        daily_goal: dailyGoal || {
          minutes_completed: 0,
          target_minutes: 30,
        },
        streak_days: profile?.streak_days || 0,
        recommended_action: continueLearning
          ? "Continue your lesson"
          : "Start learning a new topic",
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
