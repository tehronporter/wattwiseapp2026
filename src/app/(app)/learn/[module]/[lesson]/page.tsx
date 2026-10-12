import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft, ArrowRight, Bot, Check, Clock3 } from "lucide-react";
import { notFound } from "next/navigation";
import { CompleteLessonButton, LessonBookmark } from "@/components/lesson-actions";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { getLessonDetail } from "@/lib/curriculum-data";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/viewer";

type Params = { params: Promise<{ module: string; lesson: string }> };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const viewer = await getViewer();
  const values = await params;
  const lesson = viewer ? await getLessonDetail(viewer, values.module, values.lesson) : null;
  return { title: lesson?.title ?? "Lesson", description: lesson?.summary };
}

export default async function LessonPage({ params }: Params) {
  const viewer = await getViewer();
  if (!viewer) return null;
  const { module: moduleSlug, lesson: lessonSlug } = await params;
  const lesson = await getLessonDetail(viewer, moduleSlug, lessonSlug);
  if (!lesson) notFound();
  const lessonIndex = lesson.module.lessons.findIndex((item) => item.id === lesson.id);
  const previous = lesson.module.lessons[lessonIndex - 1];
  const next = lesson.module.lessons[lessonIndex + 1];
  let bookmarked = false;
  if (!viewer.isDemo) {
    const supabase = await createClient();
    const { data } = await supabase.from("lesson_bookmarks").select("lesson_id").eq("user_id", viewer.id).eq("lesson_id", lesson.id).maybeSingle();
    bookmarked = Boolean(data);
  }

  return (
    <div className="min-h-[calc(100vh-68px)] bg-white">
      <div className="sticky top-[68px] z-20 border-b border-[var(--line)] bg-white/92 backdrop-blur-xl"><div className="mx-auto flex max-w-[1000px] items-center gap-4 px-4 py-3 md:px-8"><Link href={`/learn/${lesson.module.slug}`} aria-label={`Back to ${lesson.module.title}`} className="grid size-9 place-items-center rounded-full hover:bg-[var(--surface)]"><ArrowLeft className="size-4"/></Link><div className="min-w-0 flex-1"><p className="truncate text-xs font-semibold">{lesson.title}</p><Progress value={lesson.progress} label={`${lesson.title} progress`} className="mt-1.5 max-w-[260px]"/></div>{viewer.isDemo ? <Button asChild variant="ghost" size="sm"><Link href="/sign-up">Save progress</Link></Button> : <LessonBookmark lessonId={lesson.id} moduleSlug={moduleSlug} lessonSlug={lessonSlug} bookmarked={bookmarked}/>}<Badge className="hidden sm:inline-flex">{lesson.duration} min</Badge></div></div>
      <article className="mx-auto max-w-[760px] px-5 py-12 md:py-16">
        <nav aria-label="Breadcrumb" className="flex flex-wrap items-center gap-2 text-xs text-[var(--ink-soft)]"><Link href="/learn" className="hover:text-[var(--blue)]">Learn</Link><span>/</span><Link href={`/learn/${lesson.module.slug}`} className="hover:text-[var(--blue)]">{lesson.module.title}</Link><span>/</span><span aria-current="page">{lesson.title}</span></nav>
        <div className="mt-5 flex items-center gap-3 text-xs text-[var(--ink-soft)]"><span>Lesson {lessonIndex + 1} of {lesson.module.lessons.length}</span><span>·</span><span className="flex items-center gap-1"><Clock3 className="size-3.5"/>{lesson.duration} min</span></div>
        <h1 className="mt-5 text-balance text-4xl font-bold leading-[1.04] tracking-[-.055em] md:text-[52px]">{lesson.title}</h1>
        {lesson.objectives.length > 0 && <div className="mt-8 rounded-[20px] bg-[var(--surface)] p-5"><p className="text-[10px] font-bold uppercase tracking-[.14em] text-[var(--ink-faint)]">By the end, you can</p><ul className="mt-3 space-y-2">{lesson.objectives.map((item) => <li key={item} className="flex gap-3 text-sm leading-5"><Check className="mt-0.5 size-4 shrink-0 text-[var(--blue)]"/>{item}</li>)}</ul></div>}
        <div className="mt-12 space-y-12">
          {lesson.sections.map((section, index) => <section id={`section-${index + 1}`} key={section.id}><p className="text-[10px] font-bold uppercase tracking-[.15em] text-[var(--blue)]">{String(index + 1).padStart(2, "0")} · Section {index + 1} of {lesson.sections.length}</p><h2 className="mt-3 text-2xl font-semibold tracking-[-.035em]">{section.title}</h2><div className="mt-4 whitespace-pre-line text-[17px] leading-8 text-[#42464d]">{section.body}</div></section>)}
        </div>
        <div className="mt-14 rounded-[22px] bg-[var(--ink)] p-6 text-white"><div className="flex items-start gap-4"><span className="grid size-10 shrink-0 place-items-center rounded-xl bg-[var(--on-dark-surface)] text-[#b8c6ff]"><Bot className="size-5"/></span><div><p className="font-semibold">Need another angle?</p><p className="mt-1 text-sm leading-6 text-[var(--on-dark-muted)]">Ask the tutor to explain this lesson with your track and lesson context attached.</p><Button asChild variant="secondary" size="sm" className="mt-4 border-[var(--on-dark-border)] bg-white text-[var(--ink)]"><Link href={`/tutor?prompt=${encodeURIComponent(`Explain ${lesson.title} with a jobsite example`)}&context=${encodeURIComponent(lesson.id)}`}>Ask about this lesson <ArrowRight className="size-3.5"/></Link></Button></div></div></div>
        <div className="mt-8 flex flex-wrap items-center justify-between gap-3 border-t border-[var(--line)] pt-7">{previous ? <Button asChild variant="ghost"><Link href={`/learn/${lesson.module.slug}/${previous.slug}`}><ArrowLeft className="size-4"/>Previous</Link></Button> : <span/>}<div className="flex flex-wrap gap-2">{viewer.isDemo ? <Button asChild><Link href="/sign-up">Create account to save</Link></Button> : <CompleteLessonButton lessonId={lesson.id} moduleSlug={moduleSlug} lessonSlug={lessonSlug} complete={lesson.status === "complete"}/>}<Button asChild variant="secondary"><Link href={`/practice?topic=${lesson.module.slug}&source=lesson`}>Check understanding <ArrowRight className="size-4"/></Link></Button>{next && <Button asChild><Link href={`/learn/${lesson.module.slug}/${next.slug}`}>Next lesson <ArrowRight className="size-4"/></Link></Button>}</div></div>
      </article>
    </div>
  );
}
