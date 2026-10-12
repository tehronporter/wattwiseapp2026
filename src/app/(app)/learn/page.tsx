import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, BookOpen, Calculator, Check, CircuitBoard, Clock3, HardHat, Play, PlugZap, ShieldCheck } from "lucide-react";
import { LabProgress } from "@/components/labs/progress";
import { PageHeading } from "@/components/page-heading";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { getCurriculum } from "@/lib/curriculum-data";
import { getViewer } from "@/lib/viewer";

export const metadata: Metadata = { title: "Learn", description: "Follow your personalized, code-first electrician exam curriculum." };
const icons = [CircuitBoard, BookOpen, PlugZap, Calculator, ShieldCheck, HardHat];

export default async function LearnPage() {
  const viewer = await getViewer();
  if (!viewer) return null;
  const modules = await getCurriculum(viewer);
  const lessons = modules.flatMap((module) => module.lessons);
  const complete = lessons.filter((lesson) => lesson.status === "complete").length;
  const totalMinutes = lessons.reduce((sum, lesson) => sum + Math.round(lesson.duration * (1 - lesson.progress / 100)), 0);
  const overall = lessons.length ? Math.round(lessons.reduce((sum, lesson) => sum + lesson.progress, 0) / lessons.length) : 0;
  const nextModule = modules.findIndex((item) => item.progress < 100);

  return (
    <div className="mx-auto max-w-[1180px] px-4 py-8 md:px-8 md:py-10 lg:px-10">
      <PageHeading eyebrow={`${viewer.track} track · ${viewer.jurisdiction}`} title="Your curriculum" description={`${Math.floor(totalMinutes / 60)}h ${totalMinutes % 60}m of published lessons remain.`} aside={<div className="min-w-[190px]"><div className="flex justify-between text-xs"><span className="text-[var(--ink-soft)]">Overall progress</span><b>{complete} of {lessons.length} lessons</b></div><Progress value={overall} label="Overall curriculum progress" className="mt-2"/></div>} />
      <LabProgress />
      <div className="mt-8 grid gap-4">
        {modules.map((module, index) => {
          const Icon = icons[index % icons.length];
          const active = module.progress > 0;
          const status = module.progress >= 100 ? "Complete" : active ? "In progress" : index === nextModule ? "Up next" : "Not started";
          return <Link href={`/learn/${module.slug}`} key={module.slug} className="group"><Card className="transition duration-200 group-hover:-translate-y-0.5 group-hover:border-[var(--line-strong)] group-hover:shadow-[0_14px_35px_rgba(25,30,45,.06)]"><CardContent className="grid items-center gap-5 p-5 md:grid-cols-[64px_1fr_180px_36px] md:p-6"><span className={`grid size-14 place-items-center rounded-2xl ${active ? "bg-[var(--blue-soft)] text-[var(--blue)]" : "bg-[var(--surface)] text-[var(--ink-faint)]"}`}><Icon className="size-5" strokeWidth={1.8}/></span><div><div className="flex items-center gap-2"><span className="text-[10px] font-bold tracking-[.14em] text-[var(--ink-faint)]">MODULE {module.index}</span><Badge className={module.progress >= 100 ? "h-5 bg-[var(--success-soft)] text-[var(--success)]" : "h-5"}>{module.progress >= 100 && <Check className="mr-1 size-3"/>}{status}</Badge></div><h2 className="mt-1.5 text-lg font-semibold tracking-[-.025em]">{module.title}</h2><p className="mt-1 max-w-2xl text-sm leading-5 text-[var(--ink-soft)]">{module.description}</p><div className="mt-3 flex items-center gap-4 text-[10px] text-[var(--ink-faint)] md:hidden"><span>{module.lessons.length} lessons</span><span><Clock3 className="mr-1 inline size-3"/>{module.lessons.reduce((sum, item) => sum + item.duration, 0)} min</span></div></div><div className="hidden md:block"><div className="mb-2 flex justify-between text-[10px] text-[var(--ink-faint)]"><span>{module.lessons.length} lessons · {module.lessons.reduce((sum, item) => sum + item.duration, 0)} min</span><b className="text-[var(--ink-soft)]">{module.progress}%</b></div><Progress value={module.progress} label={`${module.title} progress`}/></div><span className={`grid size-9 place-items-center rounded-full transition group-hover:translate-x-1 ${active ? "bg-[var(--blue)] text-white" : "bg-[var(--surface)] text-[var(--ink-soft)]"}`}>{active ? <Play className="size-3.5 fill-current"/> : <ArrowRight className="size-3.5"/>}</span></CardContent></Card></Link>;
        })}
      </div>
      <div className="mt-6 flex items-start gap-3 rounded-2xl bg-[var(--surface)] p-4 text-xs leading-5 text-[var(--ink-soft)]"><span className="mt-0.5 font-bold text-[var(--blue)]">Scope</span><p>Educational study support based on a national NEC foundation. Always verify the adopted code cycle, current text, and local amendments before field use.</p></div>
    </div>
  );
}

