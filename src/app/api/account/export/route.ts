import { createClient } from "@/lib/supabase/server";

export async function GET() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });

  const [profile, preferences, progress, attempts, results, sessions] = await Promise.all([
    supabase.from("profiles").select("*").eq("id", user.id).maybeSingle(),
    supabase.from("study_preferences").select("*").eq("user_id", user.id).maybeSingle(),
    supabase.from("lesson_progress").select("*").eq("user_id", user.id),
    supabase.from("quiz_attempts").select("*").eq("user_id", user.id),
    supabase.from("quiz_results").select("*").eq("user_id", user.id),
    supabase.from("tutor_sessions").select("*").eq("user_id", user.id),
  ]);

  const body = JSON.stringify({
    exported_at: new Date().toISOString(),
    account: { id: user.id, email: user.email },
    profile: profile.data,
    study_preferences: preferences.data,
    lesson_progress: progress.data ?? [],
    quiz_attempts: attempts.data ?? [],
    quiz_results: results.data ?? [],
    tutor_sessions: sessions.data ?? [],
  }, null, 2);

  return new Response(body, {
    headers: {
      "Content-Type": "application/json",
      "Content-Disposition": `attachment; filename="wattwise-data-${new Date().toISOString().slice(0, 10)}.json"`,
      "Cache-Control": "private, no-store",
    },
  });
}

