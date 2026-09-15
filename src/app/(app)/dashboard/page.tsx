import Link from "next/link";
import { ArrowRight, BookOpen, Bot, CalendarDays, CheckCircle2, ChevronRight, Clock3, Flame, Target, Zap } from "lucide-react";
import { PageHeading } from "@/components/page-heading";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";

export const metadata = { title: "Overview" };

export default function DashboardPage() {
  return (
    <div className="mx-auto max-w-[1240px] px-4 py-8 md:px-8 md:py-10 lg:px-10">
      <PageHeading eyebrow="Tuesday · Study day 12" title="Good morning, Tehron." description="One focused session moves you closer to exam day." aside={<div className="flex items-center gap-3"><CalendarDays className="size-4 text-[var(--blue)]"/><div><p className="text-[10px] font-semibold uppercase tracking-[.1em] text-[var(--ink-faint)]">Journeyman exam</p><p className="text-xs font-bold">May 24 · 68 days</p></div></div>} />

      <div className="mt-8 grid gap-5 xl:grid-cols-[1.55fr_.8fr]">
        <Link href="/learn/electrical-theory/watts-law" className="group relative overflow-hidden rounded-[26px] bg-[var(--ink)] p-6 text-white md:p-8">
          <div className="absolute -right-20 -top-24 size-72 rounded-full border-[50px] border-white/[.035]" />
          <div className="relative flex min-h-[260px] flex-col">
            <div className="flex items-center justify-between"><Badge className="bg-white/10 text-white/70">Continue learning</Badge><span className="text-xs text-white/45">Lesson 2 of 4</span></div>
            <div className="mt-auto max-w-lg"><p className="text-xs text-[#93a5ff]">Electrical theory</p><h2 className="mt-2 text-3xl font-semibold tracking-[-.045em] md:text-[38px]">Power, energy & Watt’s law</h2><p className="mt-3 text-sm leading-6 text-white/55">Pick up with power calculations and turn equipment ratings into practical circuit decisions.</p></div>
            <div className="mt-7 flex items-center gap-5"><div className="flex-1"><Progress value={62} className="bg-white/10 [&>div]:bg-white"/><p className="mt-2 text-[10px] text-white/40">62% complete · about 8 minutes left</p></div><span className="grid size-11 place-items-center rounded-full bg-white text-[var(--ink)] transition group-hover:translate-x-1"><ArrowRight className="size-4"/></span></div>
          </div>
        </Link>

        <Card className="bg-[var(--blue-soft)] border-transparent">
          <CardContent className="flex h-full min-h-[260px] flex-col p-6 md:p-7">
            <div className="flex items-start justify-between"><span className="grid size-11 place-items-center rounded-2xl bg-white text-[var(--blue)]"><Target className="size-5"/></span><span className="text-xs font-bold text-[var(--blue)]">12 min</span></div>
            <div className="mt-auto"><p className="text-[10px] font-bold uppercase tracking-[.14em] text-[var(--blue)]">Today’s focus</p><h2 className="mt-2 text-xl font-semibold tracking-[-.03em]">Grounding paths</h2><p className="mt-2 text-sm leading-6 text-[var(--ink-soft)]">You missed 3 related questions. A quick review will close the gap.</p><Button asChild variant="soft" size="sm" className="mt-5 bg-white hover:bg-white/70"><Link href="/practice">Start focused set <ChevronRight className="size-3.5"/></Link></Button></div>
          </CardContent>
        </Card>
      </div>

      <div className="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        {[{icon:Flame,value:'8',label:'day streak',detail:'+2 this week'},{icon:Clock3,value:'24m',label:'studied today',detail:'6m to goal'},{icon:CheckCircle2,value:'84%',label:'quiz accuracy',detail:'+7% this month'},{icon:Zap,value:'1,240',label:'total XP',detail:'Level 6'}].map((stat) => <Card key={stat.label}><CardContent className="p-4 md:p-5"><div className="flex items-start justify-between"><stat.icon className="size-4 text-[var(--blue)]"/><span className="text-[9px] text-[var(--ink-faint)]">{stat.detail}</span></div><p className="mt-5 text-2xl font-bold tracking-[-.045em]">{stat.value}</p><p className="mt-1 text-[11px] text-[var(--ink-soft)]">{stat.label}</p></CardContent></Card>)}
      </div>

      <div className="mt-8 grid gap-8 xl:grid-cols-[1.4fr_.8fr]">
        <section>
          <div className="mb-4 flex items-center justify-between"><h2 className="text-lg font-semibold tracking-[-.025em]">Your study plan</h2><Link href="/learn" className="text-xs font-semibold text-[var(--blue)]">View curriculum</Link></div>
          <Card><CardContent className="p-2">{[
            {status:'Now', title:'Finish Watt’s law', detail:'Electrical theory · 8 min', icon:BookOpen, href:'/learn/electrical-theory/watts-law'},
            {status:'Next', title:'10-question theory check', detail:'Adaptive practice · 12 min', icon:CheckCircle2, href:'/practice'},
            {status:'Then', title:'Article 100 definitions', detail:'Navigate the NEC · 15 min', icon:BookOpen, href:'/learn/code-navigation'},
          ].map((item,index) => <Link href={item.href} key={item.title} className="group flex items-center gap-4 rounded-2xl p-4 hover:bg-[var(--surface)]"><span className={`grid size-10 place-items-center rounded-xl ${index===0?'bg-[var(--blue)] text-white':'bg-[var(--surface)] text-[var(--ink-soft)]'}`}><item.icon className="size-4"/></span><div className="min-w-0 flex-1"><p className="text-[10px] font-bold uppercase tracking-[.12em] text-[var(--ink-faint)]">{item.status}</p><p className="mt-0.5 truncate text-sm font-semibold">{item.title}</p></div><p className="hidden text-xs text-[var(--ink-faint)] sm:block">{item.detail}</p><ChevronRight className="size-4 text-[var(--ink-faint)] transition group-hover:translate-x-0.5 group-hover:text-[var(--blue)]"/></Link>)}</CardContent></Card>
        </section>
        <section>
          <div className="mb-4 flex items-center justify-between"><h2 className="text-lg font-semibold tracking-[-.025em]">Ask WattWise</h2><span className="text-[10px] text-[var(--ink-faint)]">AI tutor</span></div>
          <Card className="overflow-hidden"><CardContent><div className="flex items-center gap-3"><span className="grid size-10 place-items-center rounded-xl bg-[var(--blue-soft)] text-[var(--blue)]"><Bot className="size-5"/></span><div><p className="text-sm font-semibold">Stuck on a concept?</p><p className="text-xs text-[var(--ink-soft)]">Ask in plain language.</p></div></div><div className="mt-5 space-y-2">{['Explain bonding vs. grounding','Help me use Table 310.16','Quiz me on branch circuits'].map(text => <Link href={`/tutor?prompt=${encodeURIComponent(text)}`} key={text} className="flex items-center justify-between rounded-xl bg-[var(--surface)] px-3 py-3 text-xs font-medium hover:text-[var(--blue)]"><span>{text}</span><ChevronRight className="size-3.5"/></Link>)}</div></CardContent></Card>
        </section>
      </div>
    </div>
  );
}
