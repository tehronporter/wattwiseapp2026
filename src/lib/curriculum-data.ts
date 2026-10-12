import "server-only";

import { cache } from "react";
import { modules as demoModules, lessonContent } from "@/lib/content";
import { createClient } from "@/lib/supabase/server";
import type { Viewer } from "@/lib/viewer";

export type CurriculumLesson = { id: string; slug: string; title: string; duration: number; status: "complete" | "current" | "not_started"; progress: number };
export type CurriculumModule = { id: string; slug: string; index: string; title: string; description: string; progress: number; lessons: CurriculumLesson[] };
export type LessonDetail = CurriculumLesson & { module: CurriculumModule; summary: string; sections: { id: string; title: string; body: string; type: string }[]; objectives: string[] };

function demoCurriculum(): CurriculumModule[] {
  return demoModules.map((module) => ({ id: module.slug, slug: module.slug, index: module.index, title: module.title, description: module.description, progress: 0, lessons: module.lessons.map((lesson) => ({ id: lesson.slug, slug: lesson.slug, title: lesson.title, duration: lesson.duration, status: "not_started" as const, progress: 0 })) }));
}

export const getCurriculum = cache(async (viewer: Viewer): Promise<CurriculumModule[]> => {
  if (viewer.isDemo) return demoCurriculum();
  const supabase = await createClient();
  const [{ data: moduleRows, error }, { data: progressRows }] = await Promise.all([
    supabase.from("modules").select("id, slug, title, description, sort_order, lessons(id, slug, title, estimated_minutes, sort_order)").eq("is_published", true).or(`exam_type.is.null,exam_type.eq.${viewer.track}`).order("sort_order", { ascending: true }),
    supabase.from("lesson_progress").select("lesson_id, status, completion_percentage").eq("user_id", viewer.id),
  ]);
  if (error) throw error;
  const progressMap = new Map((progressRows ?? []).map((row) => [row.lesson_id, row]));

  return (moduleRows ?? []).map((module, moduleIndex) => {
    const lessonsValue = Array.isArray(module.lessons) ? module.lessons : [];
    const lessons = [...lessonsValue].sort((left, right) => left.sort_order - right.sort_order).map((lesson) => {
      const progress = progressMap.get(lesson.id);
      const percentage = Number(progress?.completion_percentage ?? 0);
      return { id: lesson.id, slug: lesson.slug, title: lesson.title, duration: lesson.estimated_minutes ?? 15, status: percentage >= 100 ? "complete" as const : percentage > 0 ? "current" as const : "not_started" as const, progress: percentage };
    });
    const moduleProgress = lessons.length ? Math.round(lessons.reduce((sum, lesson) => sum + lesson.progress, 0) / lessons.length) : 0;
    return { id: module.id, slug: module.slug, index: String(moduleIndex + 1).padStart(2, "0"), title: module.title, description: module.description ?? "", progress: moduleProgress, lessons };
  });
});

export async function getCurriculumModule(viewer: Viewer, slug: string) {
  return (await getCurriculum(viewer)).find((module) => module.slug === slug) ?? null;
}

export const getLessonDetail = cache(async (viewer: Viewer, moduleSlug: string, lessonSlug: string): Promise<LessonDetail | null> => {
  const courseModule = await getCurriculumModule(viewer, moduleSlug);
  const lesson = courseModule?.lessons.find((item) => item.slug === lessonSlug);
  if (!courseModule || !lesson) return null;
  if (viewer.isDemo) {
    const content = lesson.slug === lessonContent.slug ? lessonContent : { ...lessonContent, title: lesson.title, module: courseModule.title, duration: lesson.duration };
    return { ...lesson, module: courseModule, summary: content.sections[0]?.body ?? "", sections: content.sections.map((section, index) => ({ id: String(index), title: section.title, body: section.body, type: "text" })), objectives: content.objectives };
  }

  const supabase = await createClient();
  const { data: lessonRow, error } = await supabase.from("lessons").select("summary, lesson_sections(id, heading, body_plaintext, body_markdown, section_type, sort_order)").eq("id", lesson.id).single();
  if (error) throw error;
  const sectionRows = Array.isArray(lessonRow.lesson_sections) ? lessonRow.lesson_sections : [];
  const sections = [...sectionRows].sort((left, right) => left.sort_order - right.sort_order).map((section) => ({ id: section.id, title: section.heading || "Key idea", body: section.body_plaintext || section.body_markdown || "", type: section.section_type }));
  const objectives = sections.filter((section) => /objective/i.test(section.type) || /objective/i.test(section.title)).flatMap((section) => section.body.split("\n").map((item: string) => item.replace(/^[-*]\s*/, "").trim()).filter(Boolean)).slice(0, 5);
  return { ...lesson, module: courseModule, summary: lessonRow.summary ?? sections[0]?.body ?? "", sections, objectives };
});
