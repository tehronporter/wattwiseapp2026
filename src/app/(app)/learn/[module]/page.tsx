import Link from "next/link";
import { ArrowLeft, Check, ChevronRight, Clock3, LockKeyhole, Play } from "lucide-react";
import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { modules } from "@/lib/content";

export function generateStaticParams() { return modules.map((item) => ({ module: item.slug })); }

export default async function ModulePage({ params }: { params: Promise<{ module: string }> }) {
  const { module: moduleSlug } = await params;
  const courseModule = modules.find((item) => item.slug === moduleSlug);
  if (!courseModule) notFound();
  const current = courseModule.lessons.find((item) => item.status === "current") ?? courseModule.lessons.find((item) => item.status === "ready");
  return (
    <div className="mx-auto max-w-[1020px] px-4 py-8 md:px-8 md:py-10 lg:px-10">
      <Link href="/learn" className="inline-flex items-center gap-2 text-xs font-semibold text-[var(--ink-soft)] hover:text-[var(--ink)]"><ArrowLeft className="size-3.5"/>All modules</Link>
      <div className="mt-8 grid gap-8 md:grid-cols-[1fr_220px] md:items-end"><div><p className="text-[10px] font-bold uppercase tracking-[.16em] text-[var(--blue)]">Module {courseModule.index}</p><h1 className="mt-3 text-4xl font-bold tracking-[-.055em] md:text-5xl">{courseModule.title}</h1><p className="mt-4 max-w-2xl text-sm leading-6 text-[var(--ink-soft)]">{courseModule.description}</p></div><div><div className="flex justify-between text-xs"><span className="text-[var(--ink-soft)]">Module progress</span><b>{courseModule.progress}%</b></div><Progress value={courseModule.progress} className="mt-2"/></div></div>
      <div className="mt-10 overflow-hidden rounded-[24px] border border-[var(--line)] bg-white">
        {courseModule.lessons.map((lesson,index) => {
          const isLocked = lesson.status === "locked";
          const href = isLocked ? "#" : `/learn/${courseModule.slug}/${lesson.slug}`;
          return <Link aria-disabled={isLocked} tabIndex={isLocked?-1:undefined} href={href} key={lesson.slug} className={`group flex items-center gap-4 border-b border-[var(--line)] p-4 last:border-0 md:p-5 ${isLocked?'cursor-not-allowed opacity-55':'hover:bg-[var(--surface)]'}`}><span className={`grid size-10 shrink-0 place-items-center rounded-full text-xs font-bold ${lesson.status==='complete'?'bg-[var(--blue)] text-white':lesson.status==='current'?'border-2 border-[var(--blue)] text-[var(--blue)]':'bg-[var(--surface)] text-[var(--ink-faint)]'}`}>{lesson.status==='complete'?<Check className="size-4"/>:lesson.status==='current'?<Play className="size-3.5 fill-current"/>:isLocked?<LockKeyhole className="size-3.5"/>:index+1}</span><div className="min-w-0 flex-1"><p className="text-[10px] font-semibold uppercase tracking-[.12em] text-[var(--ink-faint)]">Lesson {index+1} · {lesson.status==='current'?'In progress':lesson.status}</p><p className="mt-1 truncate text-sm font-semibold md:text-[15px]">{lesson.title}</p></div><span className="hidden items-center gap-1 text-xs text-[var(--ink-faint)] sm:flex"><Clock3 className="size-3.5"/>{lesson.duration} min</span>{!isLocked&&<ChevronRight className="size-4 text-[var(--ink-faint)] transition group-hover:translate-x-0.5 group-hover:text-[var(--blue)]"/>}</Link>;
        })}
      </div>
      {current && <div className="mt-6 flex flex-col items-start justify-between gap-4 rounded-[22px] bg-[var(--blue-soft)] p-5 sm:flex-row sm:items-center"><div><p className="text-[10px] font-bold uppercase tracking-[.12em] text-[var(--blue)]">Recommended next</p><p className="mt-1 text-sm font-semibold">{current.title}</p></div><Button asChild size="sm"><Link href={`/learn/${courseModule.slug}/${current.slug}`}>{current.status==='current'?'Resume':'Start'} lesson <ChevronRight className="size-3.5"/></Link></Button></div>}
    </div>
  );
}
