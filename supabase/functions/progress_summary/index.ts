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

function calculateStreak(goalDates: string[], today: string) {
  const completed = new Set(goalDates);
  let streak = 0;
  let cursor = new Date(`${today}T00:00:00Z`);

  while (completed.has(cursor.toISOString().slice(0, 10))) {
    streak += 1;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }

  return streak;
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

    await supabase.from("profiles").upsert(
      {
        id: user.id,
        email: user.email ?? null,
        onboarding_completed: true,
        last_active_at: new Date().toISOString(),
      },
      { onConflict: "id" }
    );

    const { data: continueRows, error: continueError } = await supabase
      .from("lesson_progress")
      .select(`
        lesson_id,
        completion_percentage,
        last_accessed_at,
        lessons (
          title,
          modules (
            title
          )
        )
      `)
      .eq("user_id", user.id)
      .gt("completion_percentage", 0)
      .lt("completion_percentage", 100)
      .order("last_accessed_at", { ascending: false })
      .limit(1);

    if (continueError) throw continueError;

    const continueLesson = firstRelation(continueRows?.[0]?.lessons);
    const continueModule = firstRelation(continueLesson?.modules);

    let continueLearning =
      continueRows && continueRows.length > 0 && continueLesson
        ? {
            lesson_id: continueRows[0].lesson_id,
            title: continueLesson.title,
            progress: Number(continueRows[0].completion_percentage) / 100,
            module_title: continueModule?.title ?? "Module",
          }
        : null;

    if (!continueLearning) {
      const { data: firstLesson, error: firstLessonError } = await supabase
        .from("lessons")
        .select(`
          id,
          title,
          modules (
            title
          )
        `)
        .eq("is_published", true)
        .order("sort_order", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (firstLessonError) throw firstLessonError;

      if (firstLesson) {
        const moduleRecord = firstRelation(firstLesson.modules);
        continueLearning = {
          lesson_id: firstLesson.id,
          title: firstLesson.title,
          progress: 0,
          module_title: moduleRecord?.title ?? "Module",
        };
      }
    }

    const today = new Date().toISOString().slice(0, 10);
    const { data: dailyGoal, error: dailyGoalError } = await supabase
      .from("daily_study_goals")
      .select("minutes_completed, target_minutes")
      .eq("user_id", user.id)
      .eq("goal_date", today)
      .maybeSingle();

    if (dailyGoalError) throw dailyGoalError;

    const { data: streakRows, error: streakError } = await supabase
      .from("daily_study_goals")
      .select("goal_date")
      .eq("user_id", user.id)
      .gt("minutes_completed", 0)
      .order("goal_date", { ascending: false })
      .limit(30);

    if (streakError) throw streakError;

    const streakDays = calculateStreak(
      (streakRows ?? []).map((row: { goal_date: string }) => row.goal_date),
      today
    );

    const recommendedAction = continueLearning
      ? continueLearning.progress > 0
        ? `Resume ${continueLearning.title}`
        : `Start ${continueLearning.title}`
      : "Browse the Learn tab";

    return json({
      success: true,
      data: {
        continue_learning: continueLearning,
        daily_goal: dailyGoal ?? {
          minutes_completed: 0,
          target_minutes: 30,
        },
        streak_days: streakDays,
        recommended_action: recommendedAction,
      },
    });
  } catch (error) {
    console.error("progress_summary error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500
    );
  }
});
