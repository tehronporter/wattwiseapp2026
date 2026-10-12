"use client";

import { useTransition } from "react";
import { Bookmark, Check } from "lucide-react";
import { markLessonComplete, toggleLessonBookmark } from "@/app/actions/lesson";
import { Button } from "@/components/ui/button";

export function LessonBookmark({ lessonId, moduleSlug, lessonSlug, bookmarked }: { lessonId: string; moduleSlug: string; lessonSlug: string; bookmarked: boolean }) {
  const [pending, startTransition] = useTransition();
  return <Button variant="ghost" size="icon" aria-label={bookmarked ? "Remove bookmark" : "Bookmark lesson"} aria-pressed={bookmarked} disabled={pending} onClick={() => startTransition(() => toggleLessonBookmark(lessonId, moduleSlug, lessonSlug))}><Bookmark className={`size-4 ${bookmarked ? "fill-current text-[var(--blue)]" : ""}`}/></Button>;
}

export function CompleteLessonButton({ lessonId, moduleSlug, lessonSlug, complete }: { lessonId: string; moduleSlug: string; lessonSlug: string; complete: boolean }) {
  const [pending, startTransition] = useTransition();
  return <Button disabled={pending || complete} onClick={() => startTransition(() => markLessonComplete(lessonId, moduleSlug, lessonSlug))}><Check className="size-4"/>{complete ? "Lesson complete" : pending ? "Saving…" : "Mark complete"}</Button>;
}

