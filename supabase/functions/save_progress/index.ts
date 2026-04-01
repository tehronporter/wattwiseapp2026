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

    const { lesson_id, completion_percentage } = await req.json();
    if (!lesson_id || completion_percentage === undefined) {
      return json(
        { success: false, error: { message: "Missing lesson_id or completion_percentage" } },
        400
      );
    }

    const now = new Date().toISOString();
    const normalized = Math.max(
      0,
      Math.min(100, completion_percentage <= 1 ? completion_percentage * 100 : completion_percentage)
    );
    const status =
      normalized >= 100 ? "completed" : normalized > 0 ? "in_progress" : "not_started";

    await supabase.from("profiles").upsert(
      {
        id: user.id,
        email: user.email ?? null,
        onboarding_completed: true,
        last_active_at: now,
      },
      { onConflict: "id" }
    );

    const { data: lesson, error: lessonError } = await supabase
      .from("lessons")
      .select("estimated_minutes")
      .eq("id", lesson_id)
      .maybeSingle();

    if (lessonError) throw lessonError;
    if (!lesson) {
      return json({ success: false, error: { message: "Lesson not found" } }, 404);
    }

    const { data: existing, error: existingError } = await supabase
      .from("lesson_progress")
      .select("completion_percentage, started_at, completed_at")
      .eq("user_id", user.id)
      .eq("lesson_id", lesson_id)
      .maybeSingle();

    if (existingError) throw existingError;

    const previousCompletion = Number(existing?.completion_percentage ?? 0);
    const completionDelta = Math.max(0, normalized - previousCompletion);

    const { error: progressError } = await supabase.from("lesson_progress").upsert(
      {
        user_id: user.id,
        lesson_id,
        status,
        completion_percentage: normalized,
        started_at: existing?.started_at ?? (normalized > 0 ? now : null),
        completed_at: normalized >= 100 ? (existing?.completed_at ?? now) : existing?.completed_at ?? null,
        study_minutes_spent: Math.max(
          0,
          Math.round(((existing?.completion_percentage ?? 0) / 100) * (lesson.estimated_minutes ?? 15))
        ) + Math.round((completionDelta / 100) * (lesson.estimated_minutes ?? 15)),
        last_accessed_at: now,
      },
      { onConflict: "user_id,lesson_id" }
    );

    if (progressError) throw progressError;

    if (completionDelta > 0) {
      const today = now.split("T")[0];
      const gainedMinutes = Math.max(
        1,
        Math.round((completionDelta / 100) * (lesson.estimated_minutes ?? 15))
      );

      const { data: dailyGoal, error: dailyGoalLookupError } = await supabase
        .from("daily_study_goals")
        .select("minutes_completed, target_minutes")
        .eq("user_id", user.id)
        .eq("goal_date", today)
        .maybeSingle();

      if (dailyGoalLookupError) throw dailyGoalLookupError;

      const completedMinutes = (dailyGoal?.minutes_completed ?? 0) + gainedMinutes;
      const targetMinutes = dailyGoal?.target_minutes ?? 30;

      const { error: dailyGoalError } = await supabase.from("daily_study_goals").upsert(
        {
          user_id: user.id,
          goal_date: today,
          target_minutes: targetMinutes,
          minutes_completed: completedMinutes,
          status: completedMinutes >= targetMinutes ? "completed" : "in_progress",
        },
        { onConflict: "user_id,goal_date" }
      );

      if (dailyGoalError) throw dailyGoalError;

      const { error: studySessionError } = await supabase.from("study_sessions").insert({
        user_id: user.id,
        session_start: now,
        session_end: now,
        total_minutes: gainedMinutes,
        activity_type: "lesson",
        context_json: { lesson_id, completion_percentage: normalized / 100 },
      });

      if (studySessionError) throw studySessionError;
    }

    return json({
      success: true,
      data: {
        success: true,
        completion_percentage: normalized / 100,
        status,
      },
    });
  } catch (error) {
    console.error("save_progress error:", error);
    return json(
      { success: false, error: { message: "Internal server error" } },
      500
    );
  }
});
