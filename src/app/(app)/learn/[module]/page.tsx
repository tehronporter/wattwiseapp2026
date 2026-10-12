import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft, Check, ChevronRight, Clock3, Play } from "lucide-react";
import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { getCurriculumModule } from "@/lib/curriculum-data";
import { getViewer } from "@/lib/viewer";

export async function generateMetadata({ params }: { params: Promise<{ module: string }> }): Promise<Metadata> {
  const viewer = await getViewer();
  const { module: slug } = await params;
  const courseModule = viewer ? await getCurriculumModule(viewer, slug) : null;
  return { title: courseModule?.title ?? "Module", description: courseModule?.description };
}

export default async function ModulePage({ params }: { params: Promise<{ module: string }> }) {
  const viewer = await getViewer();
  if (!viewer) return null;
  const { module: moduleSlug } = await params;
  const courseModule = await getCurriculumModule(viewer, moduleSlug);
  if (!courseModule) notFound();
  const current = courseModule.lessons.find((item) => item.status === "current") ?? courseModule.lessons.find((item) => item.status === "not_started");

  return (
    <div className="mx-auto max-w-[1020px] px-4 py-8 md:px-8 md:py-10 lg:px-10">
      <Link href="/learn" className="inline-flex items-center gap-2 text-xs font-semibold text-[var(--ink-soft)] hover:text-[var(--ink)]"><ArrowLeft className="size-3.5"/>All modules</Link>
      <div className="mt-8 grid gap-8 md:grid-cols-[1fr_220px] md:items-end"><div><p className="text-[10px] font-bold uppercase tracking-[.16em] text-[var(--blue)]">Module {courseModule.index}</p><h1 className="mt-3 text-4xl font-bold tracking-[-.055em] md:text-5xl">{courseModule.title}</h1><p className="mt-4 max-w-2xl text-sm leading-6 text-[var(--ink-soft)]">{courseModule.description}</p><Button asChild variant="secondary" size="sm" className="mt-5"><Link href={`/practice?topic=${courseModule.slug}&source=module`}>Practice this module</Link></Button></div><div><div className="flex justify-between text-xs"><span className="text-[var(--ink-soft)]">Module progress</span><b>{courseModule.progress}%</b></div><Progress value={courseModule.progress} label={`${courseModule.title} progress`} className="mt-2"/><p className="mt-2 text-[10px] leading-4 text-[var(--ink-faint)]">Derived from lesson completion. Quiz mastery is reported separately.</p></div></div>
      <div className="mt-10 overflow-hidden rounded-[24px] border border-[var(--line)] bg-white">
        {courseModule.lessons.map((lesson, index) => {
          const status = lesson.status === "complete" ? "Complete" : lesson.status === "current" ? "In progress" : "Not started";
          return <Link href={`/learn/${courseModule.slug}/${lesson.slug}`} key={lesson.slug} className="group flex items-center gap-4 border-b border-[var(--line)] p-4 last:border-0 hover:bg-[var(--surface)] md:p-5"><span className={`grid size-10 shrink-0 place-items-center rounded-full text-xs font-bold ${lesson.status === "complete" ? "bg-[var(--blue)] text-white" : lesson.status === "current" ? "border-2 border-[var(--blue)] text-[var(--blue)]" : "bg-[var(--surface)] text-[var(--ink-faint)]"}`}>{lesson.status === "complete" ? <Check className="size-4"/> : lesson.status === "current" ? <Play className="size-3.5 fill-current"/> : index + 1}</span><div className="min-w-0 flex-1"><p className="text-[10px] font-semibold uppercase tracking-[.12em] text-[var(--ink-faint)]">Lesson {index + 1} · {status}</p><p className="mt-1 truncate text-sm font-semibold md:text-[15px]">{lesson.title}</p></div><span className="hidden items-center gap-1 text-xs text-[var(--ink-faint)] sm:flex"><Clock3 className="size-3.5"/>{lesson.duration} min</span><ChevronRight className="size-4 text-[var(--ink-faint)] transition group-hover:translate-x-0.5 group-hover:text-[var(--blue)]"/></Link>;
        })}
      </div>
      {current && <div className="sticky bottom-4 mt-6 flex flex-col items-start justify-between gap-4 rounded-[22px] border border-white/60 bg-[var(--blue-soft)]/95 p-5 shadow-[0_16px_50px_rgba(30,50,100,.12)] backdrop-blur-xl sm:flex-row sm:items-center"><div><p className="text-[10px] font-bold uppercase tracking-[.12em] text-[var(--blue)]">Recommended next</p><p className="mt-1 text-sm font-semibold">{current.title}</p></div><Button asChild size="sm"><Link href={`/learn/${courseModule.slug}/${current.slug}`}>{current.status === "current" ? "Resume" : "Start"} lesson <ChevronRight className="size-3.5"/></Link></Button></div>}
    </div>
  );
}
