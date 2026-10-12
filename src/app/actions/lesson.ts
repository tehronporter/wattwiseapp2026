"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function markLessonComplete(lessonId: string, moduleSlug: string, lessonSlug: string) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  const { error } = await supabase.functions.invoke("save_progress", { body: { lesson_id: lessonId, completion_percentage: 100 } });
  if (error) throw new Error("Unable to save lesson progress.");
  revalidatePath("/dashboard");
  revalidatePath("/learn");
  revalidatePath(`/learn/${moduleSlug}`);
  revalidatePath(`/learn/${moduleSlug}/${lessonSlug}`);
}

export async function toggleLessonBookmark(lessonId: string, moduleSlug: string, lessonSlug: string) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  const { data: existing } = await supabase.from("lesson_bookmarks").select("lesson_id").eq("user_id", user.id).eq("lesson_id", lessonId).maybeSingle();
  const operation = existing
    ? supabase.from("lesson_bookmarks").delete().eq("user_id", user.id).eq("lesson_id", lessonId)
    : supabase.from("lesson_bookmarks").insert({ user_id: user.id, lesson_id: lessonId });
  const { error } = await operation;
  if (error) throw error;
  revalidatePath(`/learn/${moduleSlug}/${lessonSlug}`);
}
