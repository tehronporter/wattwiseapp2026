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
    const { lesson_id, completion_percentage } = await req.json();

    if (!lesson_id || completion_percentage === undefined) {
      return new Response(
        JSON.stringify({ error: "Missing lesson_id or completion_percentage" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Clamp percentage between 0 and 100
    const clamped = Math.max(0, Math.min(100, completion_percentage));

    // Upsert lesson progress
    const { data, error } = await supabase
      .from("lesson_progress")
      .upsert(
        {
          user_id: userId,
          lesson_id,
          completion_percentage: clamped,
        },
        { onConflict: "user_id,lesson_id" }
      )
      .select();

    if (error) throw error;

    // If lesson is completed, update study session and streak
    if (clamped >= 100) {
      const today = new Date().toISOString().split("T")[0];

      // Create or update study session
      await supabase.from("study_sessions").insert({
        user_id: userId,
        lesson_id,
        session_date: today,
        minutes_spent: 0, // Will be updated by trigger
      });

      // Update daily goal
      const { data: existingGoal } = await supabase
        .from("daily_study_goals")
        .select("minutes_completed")
        .eq("user_id", userId)
        .eq("goal_date", today)
        .single();

      if (existingGoal) {
        await supabase
          .from("daily_study_goals")
          .update({ minutes_completed: existingGoal.minutes_completed + 30 })
          .eq("user_id", userId)
          .eq("goal_date", today);
      } else {
        await supabase.from("daily_study_goals").insert({
          user_id: userId,
          goal_date: today,
          minutes_completed: 30,
          target_minutes: 30,
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        completion_percentage: clamped,
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
