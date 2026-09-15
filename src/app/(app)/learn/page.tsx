import Link from "next/link";
import { ArrowRight, Check, Clock3, Play } from "lucide-react";
import { PageHeading } from "@/components/page-heading";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { modules } from "@/lib/content";

export const metadata = { title: "Learn" };

export default function LearnPage() {
  const complete = modules.flatMap((item) => item.lessons).filter((item) => item.status === "complete").length;
  const total = modules.flatMap((item) => item.lessons).length;
  return (
    <div className="mx-auto max-w-[1180px] px-4 py-8 md:px-8 md:py-10 lg:px-10">
      <PageHeading eyebrow="Journeyman track" title="Your curriculum" description="A code-first path from core theory to confident exam decisions." aside={<div className="min-w-[180px]"><div className="flex justify-between text-xs"><span className="text-[var(--ink-soft)]">Overall progress</span><b>{complete}/{total}</b></div><Progress value={31} className="mt-2"/></div>} />
      <div className="mt-8 grid gap-4">
        {modules.map((module) => {
          const Icon = module.icon;
          const active = module.progress > 0;
          return <Link href={`/learn/${module.slug}`} key={module.slug} className="group"><Card className="transition duration-200 group-hover:-translate-y-0.5 group-hover:border-[var(--line-strong)] group-hover:shadow-[0_14px_35px_rgba(25,30,45,.06)]"><CardContent className="grid items-center gap-5 p-5 md:grid-cols-[64px_1fr_180px_36px] md:p-6"><span className={`grid size-14 place-items-center rounded-2xl ${active?'bg-[var(--blue-soft)] text-[var(--blue)]':'bg-[var(--surface)] text-[var(--ink-faint)]'}`}><Icon className="size-5" strokeWidth={1.8}/></span><div><div className="flex items-center gap-2"><span className="text-[10px] font-bold tracking-[.14em] text-[var(--ink-faint)]">MODULE {module.index}</span>{module.progress === 100 && <Badge className="h-5 bg-[#e8f4ee] text-[var(--success)]"><Check className="mr-1 size-3"/>Complete</Badge>}</div><h2 className="mt-1.5 text-lg font-semibold tracking-[-.025em]">{module.title}</h2><p className="mt-1 max-w-2xl text-sm leading-5 text-[var(--ink-soft)]">{module.description}</p><div className="mt-3 flex items-center gap-4 text-[10px] text-[var(--ink-faint)] md:hidden"><span>{module.lessons.length} lessons</span><span><Clock3 className="mr-1 inline size-3"/>{module.lessons.reduce((sum,item)=>sum+item.duration,0)} min</span></div></div><div className="hidden md:block"><div className="mb-2 flex justify-between text-[10px] text-[var(--ink-faint)]"><span>{module.lessons.length} lessons · {module.lessons.reduce((sum,item)=>sum+item.duration,0)} min</span><b className="text-[var(--ink-soft)]">{module.progress}%</b></div><Progress value={module.progress}/></div><span className={`grid size-9 place-items-center rounded-full transition group-hover:translate-x-1 ${active?'bg-[var(--blue)] text-white':'bg-[var(--surface)] text-[var(--ink-soft)]'}`}>{active?<Play className="size-3.5 fill-current"/>:<ArrowRight className="size-3.5"/>}</span></CardContent></Card></Link>;
        })}
      </div>
      <div className="mt-6 flex items-start gap-3 rounded-2xl bg-[var(--surface)] p-4 text-xs leading-5 text-[var(--ink-soft)]"><span className="mt-0.5 font-bold text-[var(--blue)]">Note</span><p>Your curriculum uses the national NEC baseline and California exam guidance. Confirm the adopted code cycle and local amendments for field decisions.</p></div>
    </div>
  );
}
