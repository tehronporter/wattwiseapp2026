import Link from "next/link";
import { ArrowRight, Bot, ChevronRight, CircleAlert, Clock3, TrendingUp } from "lucide-react";
import { PageHeading } from "@/components/page-heading";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

export const metadata = { title: "Review" };

const weakAreas = [
  { title:"Grounding & bonding", accuracy:58, misses:5, note:"Fault-current paths and electrode sizing" },
  { title:"Branch circuits", accuracy:67, misses:3, note:"Continuous loads and required protection" },
  { title:"Code navigation", accuracy:72, misses:2, note:"Exceptions and specific-use articles" },
];

export default function ReviewPage() {
  return <div className="mx-auto max-w-[1120px] px-4 py-8 md:px-8 md:py-10 lg:px-10"><PageHeading eyebrow="Performance center" title="Turn misses into mastery" description="Your results are organized into the few topics that will improve readiness fastest."/>
    <div className="mt-8 grid gap-4 md:grid-cols-3">{[['84%','Overall accuracy','+7% this month'],['12','Questions reviewed','4 this week'],['76%','Readiness score','On track']].map(([value,label,detail],i)=><Card key={label}><CardContent><div className="flex items-center justify-between"><span className="text-[10px] font-semibold uppercase tracking-[.1em] text-[var(--ink-faint)]">{label}</span>{i===0&&<TrendingUp className="size-4 text-[var(--success)]"/>}</div><p className="mt-5 text-3xl font-bold tracking-[-.05em]">{value}</p><p className="mt-1 text-xs text-[var(--ink-soft)]">{detail}</p></CardContent></Card>)}</div>
    <div className="mt-9 grid gap-8 lg:grid-cols-[1.25fr_.75fr]"><section><div className="mb-4 flex items-center justify-between"><h2 className="text-lg font-semibold tracking-[-.03em]">Focus areas</h2><Button asChild size="sm"><Link href="/practice">Practice all <ArrowRight className="size-3.5"/></Link></Button></div><Card><CardContent className="p-2">{weakAreas.map((area)=><div key={area.title} className="flex flex-col gap-4 rounded-2xl p-4 hover:bg-[var(--surface)] sm:flex-row sm:items-center"><span className="grid size-10 shrink-0 place-items-center rounded-xl bg-[#fff2ec] text-[#b45131]"><CircleAlert className="size-4"/></span><div className="min-w-0 flex-1"><div className="flex justify-between"><p className="text-sm font-semibold">{area.title}</p><b className="text-xs">{area.accuracy}%</b></div><p className="mt-1 text-[11px] text-[var(--ink-soft)]">{area.note}</p><div className="mt-2 h-1 rounded-full bg-[var(--line)]"><div className="h-full rounded-full bg-[var(--blue)]" style={{width:`${area.accuracy}%`}}/></div></div><div className="flex items-center gap-2"><Link href={`/tutor?prompt=${encodeURIComponent(`Help me review ${area.title}`)}`} className="grid size-9 place-items-center rounded-full bg-[var(--blue-soft)] text-[var(--blue)]" aria-label={`Ask tutor about ${area.title}`}><Bot className="size-4"/></Link><Link href="/practice" className="grid size-9 place-items-center rounded-full border border-[var(--line)]"><ChevronRight className="size-4"/></Link></div></div>)}</CardContent></Card></section>
      <section><h2 className="mb-4 text-lg font-semibold tracking-[-.03em]">Recent sets</h2><Card><CardContent className="space-y-5">{[{name:'Theory check',score:'9/10',time:'Yesterday'},{name:'Grounding focus',score:'6/10',time:'Mar 14'},{name:'Mixed quick set',score:'8/10',time:'Mar 12'}].map(item=><div key={item.name} className="flex items-center gap-3"><span className="grid size-9 place-items-center rounded-xl bg-[var(--surface)]"><Clock3 className="size-3.5 text-[var(--ink-soft)]"/></span><div className="min-w-0 flex-1"><p className="truncate text-xs font-semibold">{item.name}</p><p className="mt-0.5 text-[10px] text-[var(--ink-faint)]">{item.time}</p></div><b className="text-xs">{item.score}</b></div>)}</CardContent></Card></section>
    </div>
  </div>;
}
