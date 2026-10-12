import "server-only";

import { cache } from "react";
import { env, isSupabaseConfigured } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";

export type Viewer = {
  id: string;
  email: string;
  fullName: string;
  initials: string;
  track: "apprentice" | "journeyman" | "master";
  jurisdiction: string;
  jurisdictionCode: string;
  dailyGoalMinutes: number;
  examDate: string | null;
  timezone: string;
  onboardingComplete: boolean;
  isDemo: boolean;
};

const demoViewer: Viewer = {
  id: "demo-user",
  email: "demo@wattwise.app",
  fullName: "Demo Learner",
  initials: "DL",
  track: "journeyman",
  jurisdiction: "California",
  jurisdictionCode: "CA",
  dailyGoalMinutes: 30,
  examDate: null,
  timezone: "America/Los_Angeles",
  onboardingComplete: true,
  isDemo: true,
};

function initialsFor(name: string, email: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length > 0) return parts.slice(0, 2).map((part) => part[0]).join("").toUpperCase();
  return email.slice(0, 2).toUpperCase();
}

export const getViewer = cache(async (): Promise<Viewer | null> => {
  if (!isSupabaseConfigured()) return env.demoMode ? demoViewer : null;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: profile } = await supabase
    .from("profiles")
    .select(`
      display_name,
      exam_type,
      daily_study_goal_minutes,
      onboarding_completed,
      exam_date,
      timezone,
      jurisdictions (code, name)
    `)
    .eq("id", user.id)
    .maybeSingle();

  const jurisdictionValue = profile?.jurisdictions;
  const jurisdiction = Array.isArray(jurisdictionValue)
    ? jurisdictionValue[0]
    : jurisdictionValue;
  const email = user.email ?? "learner@wattwise.app";
  const fullName = profile?.display_name?.trim() || user.user_metadata?.full_name || "WattWise Learner";
  const track = ["apprentice", "journeyman", "master"].includes(profile?.exam_type ?? "")
    ? (profile?.exam_type as Viewer["track"])
    : "journeyman";

  return {
    id: user.id,
    email,
    fullName,
    initials: initialsFor(fullName, email),
    track,
    jurisdiction: jurisdiction?.name ?? "Choose jurisdiction",
    jurisdictionCode: jurisdiction?.code ?? "",
    dailyGoalMinutes: profile?.daily_study_goal_minutes ?? 30,
    examDate: profile?.exam_date ?? null,
    timezone: profile?.timezone ?? "America/Los_Angeles",
    onboardingComplete: profile?.onboarding_completed ?? false,
    isDemo: false,
  };
});
