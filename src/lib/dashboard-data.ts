import "server-only";

import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import type { Viewer } from "@/lib/viewer";

export type DashboardData = {
  greeting: string;
  dateLabel: string;
  examLabel: string;
  examDays: number | null;
  hasStarted: boolean;
  continueLearning: { title: string; moduleTitle: string; progress: number; href: string } | null;
  dailyMinutes: number;
  dailyGoal: number;
  streak: number;
  accuracy: number | null;
  readiness: number | null;
  completedLessons: number;
  totalLessons: number;
  weakTopics: { slug: string; title: string; mastery: number }[];
  recentSets: { id: string; score: string; date: string }[];
};

function timeParts(timezone: string) {
  const now = new Date();
  const hour = Number(new Intl.DateTimeFormat("en-US", { hour: "numeric", hour12: false, timeZone: timezone }).format(now));
  const greeting = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";
  const dateLabel = new Intl.DateTimeFormat("en-US", { weekday: "long", month: "short", day: "numeric", timeZone: timezone }).format(now);
  return { greeting, dateLabel };
}

function examTarget(examDate: string | null) {
  if (!examDate) return { examLabel: "Not scheduled", examDays: null };
  const target = new Date(`${examDate}T12:00:00`);
  return {
    examLabel: new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(target),
    examDays: Math.max(0, Math.ceil((target.getTime() - Date.now()) / 86_400_000)),
  };
}

function relativeDate(value: string) {
  const days = Math.floor((Date.now() - new Date(value).getTime()) / 86_400_000);
  if (days <= 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days < 7) return `${days} days ago`;
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(new Date(value));
}

function titleFromSlug(slug: string) {
  return slug.split("-").map((part) => `${part[0]?.toUpperCase() ?? ""}${part.slice(1)}`).join(" ");
}

export const getDashboardData = cache(async (viewer: Viewer): Promise<DashboardData> => {
  const timezone = viewer.timezone;
  const temporal = timeParts(timezone);
  const target = examTarget(viewer.examDate);
  if (viewer.isDemo) {
    return {
      ...temporal, ...target, hasStarted: false, continueLearning: null, dailyMinutes: 0,
      dailyGoal: viewer.dailyGoalMinutes, streak: 0, accuracy: null, readiness: null,
      completedLessons: 0, totalLessons: 92, weakTopics: [], recentSets: [],
    };
  }

  const supabase = await createClient();
  const [summaryResponse, resultsResponse, masteryResponse, completedResponse, lessonsResponse] = await Promise.all([
    supabase.functions.invoke("progress_summary", { body: {} }),
    supabase.from("quiz_results").select("quiz_attempt_id, correct_count, total_count, created_at, weak_topics").eq("user_id", viewer.id).order("created_at", { ascending: false }).limit(20),
    supabase.from("topic_mastery").select("topic_slug, score").eq("user_id", viewer.id).order("score", { ascending: true }).limit(6),
    supabase.from("lesson_progress").select("*", { count: "exact", head: true }).eq("user_id", viewer.id).eq("status", "completed"),
    supabase.from("lessons").select("*", { count: "exact", head: true }).eq("is_published", true).eq("publish_status", "published"),
  ]);

  const envelope = summaryResponse.data as { success?: boolean; data?: { continue_learning?: { lesson_id: string; title: string; progress: number; module_title: string } | null; daily_goal?: { minutes_completed: number; target_minutes: number }; streak_days?: number; has_started_content?: boolean } } | null;
  const summary = envelope?.data;
  const continueItem = summary?.continue_learning;
  let continueLearning: DashboardData["continueLearning"] = continueItem ? { title: continueItem.title, moduleTitle: continueItem.module_title, progress: continueItem.progress, href: "/learn" } : null;
  if (continueItem?.lesson_id) {
    const { data: lesson } = await supabase.from("lessons").select("slug, modules(slug)").eq("id", continueItem.lesson_id).maybeSingle();
    const moduleValue = lesson?.modules;
    const moduleRow = Array.isArray(moduleValue) ? moduleValue[0] : moduleValue;
    if (lesson?.slug && moduleRow?.slug) continueLearning = { ...continueLearning!, href: `/learn/${moduleRow.slug}/${lesson.slug}` };
  }

  const results = resultsResponse.data ?? [];
  const totalQuestions = results.reduce((sum, row) => sum + Number(row.total_count || 0), 0);
  const totalCorrect = results.reduce((sum, row) => sum + Number(row.correct_count || 0), 0);
  const accuracy = totalQuestions ? Math.round((totalCorrect / totalQuestions) * 100) : null;
  const completedLessons = completedResponse.count ?? 0;
  const totalLessons = lessonsResponse.count ?? 0;
  const lessonRatio = totalLessons ? completedLessons / totalLessons : 0;
  const masteryRows = masteryResponse.data ?? [];
  const topicCoverage = masteryRows.length ? masteryRows.reduce((sum, row) => sum + Number(row.score), 0) / masteryRows.length : 0;
  const readiness = totalQuestions >= 10 ? Math.round((lessonRatio * 0.25 + (accuracy! / 100) * 0.55 + topicCoverage * 0.2) * 100) : null;

  return {
    ...temporal,
    ...target,
    hasStarted: Boolean(summary?.has_started_content),
    continueLearning,
    dailyMinutes: summary?.daily_goal?.minutes_completed ?? 0,
    dailyGoal: summary?.daily_goal?.target_minutes ?? viewer.dailyGoalMinutes,
    streak: summary?.streak_days ?? 0,
    accuracy,
    readiness,
    completedLessons,
    totalLessons,
    weakTopics: masteryRows.slice(0, 3).map((row) => ({ slug: row.topic_slug, title: titleFromSlug(row.topic_slug), mastery: Math.round(Number(row.score) * 100) })),
    recentSets: results.slice(0, 5).map((row) => ({ id: row.quiz_attempt_id, score: `${row.correct_count}/${row.total_count}`, date: relativeDate(row.created_at) })),
  };
});
