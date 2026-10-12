"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";

export type ProfileFormState = { message?: string; success?: boolean };

const onboardingSchema = z.object({
  track: z.enum(["apprentice", "journeyman", "master"]),
  jurisdiction: z.string().regex(/^[A-Z]{2}$/),
  examDate: z.union([z.iso.date(), z.literal("")]),
  dailyGoal: z.coerce.number().int().min(10).max(180),
  reminderTime: z.union([z.string().regex(/^\d{2}:\d{2}$/), z.literal("")]),
  timezone: z.string().min(1).max(80),
});

export async function completeOnboarding(
  _state: ProfileFormState,
  formData: FormData,
): Promise<ProfileFormState> {
  const parsed = onboardingSchema.safeParse({
    track: formData.get("track"),
    jurisdiction: formData.get("jurisdiction"),
    examDate: formData.get("examDate"),
    dailyGoal: formData.get("dailyGoal"),
    reminderTime: formData.get("reminderTime"),
    timezone: formData.get("timezone") || "America/Los_Angeles",
  });
  if (!parsed.success) return { message: "Review the highlighted study-plan details and try again." };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { message: "Your session expired. Sign in and try again." };

  const { data: jurisdiction, error: jurisdictionError } = await supabase
    .from("jurisdictions")
    .select("id")
    .eq("code", parsed.data.jurisdiction)
    .single();
  if (jurisdictionError || !jurisdiction) return { message: "That jurisdiction is not available yet." };

  const { error: profileError } = await supabase
    .from("profiles")
    .update({
      exam_type: parsed.data.track,
      jurisdiction_id: jurisdiction.id,
      exam_date: parsed.data.examDate || null,
      daily_study_goal_minutes: parsed.data.dailyGoal,
      timezone: parsed.data.timezone,
      onboarding_completed: true,
      updated_at: new Date().toISOString(),
    })
    .eq("id", user.id);
  if (profileError) return { message: profileError.message };

  const { error: preferenceError } = await supabase.from("study_preferences").upsert({
    user_id: user.id,
    wants_daily_reminders: Boolean(parsed.data.reminderTime),
    preferred_reminder_time: parsed.data.reminderTime || null,
  }, { onConflict: "user_id" });
  if (preferenceError) return { message: preferenceError.message };

  revalidatePath("/", "layout");
  redirect("/dashboard");
}

const settingsSchema = onboardingSchema.extend({
  displayName: z.string().trim().min(2).max(80),
});

export async function updateProfile(
  _state: ProfileFormState,
  formData: FormData,
): Promise<ProfileFormState> {
  const parsed = settingsSchema.safeParse({
    displayName: formData.get("displayName"),
    track: formData.get("track"),
    jurisdiction: formData.get("jurisdiction"),
    examDate: formData.get("examDate"),
    dailyGoal: formData.get("dailyGoal"),
    reminderTime: formData.get("reminderTime"),
    timezone: formData.get("timezone") || "America/Los_Angeles",
  });
  if (!parsed.success) return { message: "Check the form values and try again." };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { message: "Your session expired. Sign in again." };
  const { data: jurisdiction } = await supabase.from("jurisdictions").select("id").eq("code", parsed.data.jurisdiction).single();
  if (!jurisdiction) return { message: "That jurisdiction is not available." };

  const [{ error: profileError }, { error: preferencesError }] = await Promise.all([
    supabase.from("profiles").update({
      display_name: parsed.data.displayName,
      exam_type: parsed.data.track,
      jurisdiction_id: jurisdiction.id,
      exam_date: parsed.data.examDate || null,
      daily_study_goal_minutes: parsed.data.dailyGoal,
      timezone: parsed.data.timezone,
      updated_at: new Date().toISOString(),
    }).eq("id", user.id),
    supabase.from("study_preferences").upsert({
      user_id: user.id,
      wants_daily_reminders: Boolean(parsed.data.reminderTime),
      preferred_reminder_time: parsed.data.reminderTime || null,
    }, { onConflict: "user_id" }),
  ]);
  if (profileError || preferencesError) return { message: profileError?.message ?? preferencesError?.message };

  revalidatePath("/", "layout");
  return { message: "Settings saved.", success: true };
}

