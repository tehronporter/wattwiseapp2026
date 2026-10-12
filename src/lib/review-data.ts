import "server-only";

import { cache } from "react";
import { getDashboardData } from "@/lib/dashboard-data";
import { createClient } from "@/lib/supabase/server";
import type { Viewer } from "@/lib/viewer";

export type MissedQuestion = { attemptId: string; questionId: string; question: string; userAnswer: string; correctAnswer: string; explanation: string; reference: string | null; topic: string };
export type ReviewData = { accuracy: number | null; readiness: number | null; misses: MissedQuestion[]; focusAreas: { slug: string; title: string; mastery: number; misses: number }[]; recentSets: { id: string; score: string; date: string }[] };

function slugify(value: string) { return value.toLowerCase().replace(/&/g, "and").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""); }

export const getReviewData = cache(async (viewer: Viewer): Promise<ReviewData> => {
  const dashboard = await getDashboardData(viewer);
  if (viewer.isDemo) return { accuracy: dashboard.accuracy, readiness: dashboard.readiness, misses: [], focusAreas: [], recentSets: [] };
  const supabase = await createClient();
  const { data } = await supabase.from("quiz_results").select("quiz_attempt_id, results_json").eq("user_id", viewer.id).order("created_at", { ascending: false }).limit(20);
  const misses: MissedQuestion[] = [];
  for (const row of data ?? []) {
    const results = Array.isArray(row.results_json) ? row.results_json : [];
    for (const result of results) {
      if (result?.is_correct !== false) continue;
      misses.push({ attemptId: row.quiz_attempt_id, questionId: String(result.question_id ?? ""), question: String(result.question ?? "Question unavailable"), userAnswer: String(result.user_answer ?? "Not answered"), correctAnswer: String(result.correct_answer ?? ""), explanation: String(result.explanation ?? ""), reference: result.reference_code ? String(result.reference_code) : null, topic: String(result.topic_titles?.[0] ?? result.topics?.[0] ?? "Mixed practice") });
    }
  }
  const missCount = new Map<string, number>();
  misses.forEach((miss) => missCount.set(slugify(miss.topic), (missCount.get(slugify(miss.topic)) ?? 0) + 1));
  const focusAreas = dashboard.weakTopics.map((topic) => ({ ...topic, misses: missCount.get(topic.slug) ?? misses.filter((miss) => slugify(miss.topic) === topic.slug).length }));
  return { accuracy: dashboard.accuracy, readiness: dashboard.readiness, misses: misses.slice(0, 30), focusAreas, recentSets: dashboard.recentSets };
});

