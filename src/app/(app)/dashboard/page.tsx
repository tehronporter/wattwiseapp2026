import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, BookOpen, CalendarDays, CheckCircle2, ChevronRight, Clock3, Flame, Target } from "lucide-react";
import { PageHeading } from "@/components/page-heading";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { getDashboardData } from "@/lib/dashboard-data";
import { getViewer } from "@/lib/viewer";

export const metadata: Metadata = { title: "Overview", description: "Your personalized WattWise study plan and readiness overview." };

export default async function DashboardPage() {
  const viewer = await getViewer();
  if (!viewer) return null;
  const data = await getDashboardData(viewer);
  const firstName = viewer.fullName.split(/\s+/)[0];
  const focus = data.weakTopics[0];

  return (
    <div className="mx-auto max-w-[1240px] px-4 py-8 md:px-8 md:py-10 lg:px-10">
      <PageHeading
        eyebrow={data.dateLabel}
        title={`${data.greeting}, ${firstName}.`}
        description={data.hasStarted ? "One focused session moves you closer to exam day." : "Let’s establish your baseline and build today’s plan."}
        aside={<Link href="/settings#exam-plan" className="flex items-center gap-3 rounded-xl p-2 hover:bg-[var(--surface)]"><CalendarDays className="size-4 text-[var(--blue)]"/><div><p className="text-[10px] font-semibold uppercase tracking-[.1em] text-[var(--ink-faint)]">{viewer.track} exam</p><p className="text-xs font-bold">{data.examLabel}{data.examDays !== null ? ` · ${data.examDays} days` : ""}</p></div></Link>}
      />

      {!data.hasStarted ? <NewUserStart /> : <ReturningHero data={data} focus={focus} />}

      <div className="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat icon={Flame} value={String(data.streak)} label="day streak" detail={data.streak ? "Keep it going" : "Starts with a study day"} />
        <Stat icon={Clock3} value={`${data.dailyMinutes}m`} label="studied today" detail={`${data.dailyMinutes} / ${data.dailyGoal} min goal`} />
        <Stat icon={CheckCircle2} value={data.accuracy === null ? "—" : `${data.accuracy}%`} label="quiz accuracy" detail={data.accuracy === null ? "Complete a set" : "Recent attempts"} />
        <Stat icon={Target} value={data.readiness === null ? "—" : `${data.readiness}%`} label="readiness" detail={data.readiness === null ? "Unlocks after 10 answers" : "Derived, not a pass guarantee"} />
      </div>

      <div className="mt-8 grid gap-8 xl:grid-cols-[1.4fr_.8fr]">
        <section>
          <div className="mb-4 flex items-center justify-between"><h2 className="text-lg font-semibold tracking-[-.025em]">Your study plan</h2><Link href="/learn" className="text-xs font-semibold text-[var(--blue)]">View curriculum</Link></div>
          <Card><CardContent className="p-2">
            {data.continueLearning && <PlanRow status="Now" title={`${Math.round(data.continueLearning.progress * 100) ? "Resume" : "Start"} ${data.continueLearning.title}`} detail={data.continueLearning.moduleTitle} href={data.continueLearning.href} primary />}
            <PlanRow status={data.continueLearning ? "Next" : "Now"} title={focus ? `Practice ${focus.title}` : "Take a 10-question placement set"} detail="Adaptive practice · about 12 min" href={focus ? `/practice?topic=${focus.slug}&source=study-plan` : "/practice?source=placement&count=10"} primary={!data.continueLearning} />
            <PlanRow status="Then" title="Review explanations and code paths" detail="Performance center" href="/review" />
          </CardContent></Card>
        </section>
        <section>
          <div className="mb-4 flex items-center justify-between"><h2 className="text-lg font-semibold tracking-[-.025em]">Progress</h2><span className="text-[10px] text-[var(--ink-faint)]">Published lessons</span></div>
          <Card><CardContent><p className="text-3xl font-bold tracking-[-.05em]">{data.completedLessons} <span className="text-base font-medium text-[var(--ink-faint)]">of {data.totalLessons}</span></p><p className="mt-2 text-xs text-[var(--ink-soft)]">lessons complete</p><Progress value={data.totalLessons ? data.completedLessons / data.totalLessons * 100 : 0} label="Curriculum progress" className="mt-5"/><Button asChild variant="secondary" size="sm" className="mt-6"><Link href="/learn">Continue learning <ArrowRight className="size-3.5"/></Link></Button></CardContent></Card>
        </section>
      </div>
    </div>
  );
}

function NewUserStart() {
  return <div className="mt-8 grid gap-5 xl:grid-cols-[1.55fr_.8fr]"><Card className="overflow-hidden bg-[var(--ink)] text-white"><CardContent className="flex min-h-[260px] flex-col p-6 md:p-8"><Badge className="w-fit bg-[var(--on-dark-surface)] text-[var(--on-dark-muted)]">Day one</Badge><div className="mt-auto"><h2 className="max-w-lg text-3xl font-semibold tracking-[-.045em]">Start with a 10-question placement set.</h2><p className="mt-3 max-w-lg text-sm leading-6 text-[var(--on-dark-muted)]">Your results seed topic mastery so the next lesson and practice set are based on evidence, not generic progress.</p><Button asChild variant="secondary" className="mt-6 border-0 bg-[#f7f8fb] hover:bg-white"><Link href="/practice?source=placement&count=10" style={{ color: "var(--ink)" }}>Take placement set <ArrowRight className="size-4"/></Link></Button></div></CardContent></Card><Card><CardContent className="flex min-h-[260px] flex-col"><p className="text-[10px] font-bold uppercase tracking-[.14em] text-[var(--blue)]">Setup checklist</p><div className="mt-5 space-y-3">{["Profile and license track", "Jurisdiction context", "Daily study goal"].map((item) => <p key={item} className="flex items-center gap-3 text-sm"><CheckCircle2 className="size-4 text-[var(--success)]"/>{item}</p>)}<p className="flex items-center gap-3 text-sm text-[var(--ink-soft)]"><span className="size-4 rounded-full border border-[var(--line-strong)]"/>Placement baseline</p></div><Link href="/settings" className="mt-auto text-xs font-semibold text-[var(--blue)]">Review setup</Link></CardContent></Card></div>;
}

function ReturningHero({ data, focus }: { data: Awaited<ReturnType<typeof getDashboardData>>; focus: Awaited<ReturnType<typeof getDashboardData>>["weakTopics"][number] | undefined }) {
  return <div className="mt-8 grid gap-5 xl:grid-cols-[1.55fr_.8fr]">{data.continueLearning && <Link href={data.continueLearning.href} className="group relative overflow-hidden rounded-[26px] bg-[var(--ink)] p-6 text-white md:p-8"><div className="relative flex min-h-[260px] flex-col"><div className="flex items-center justify-between"><Badge className="bg-[var(--on-dark-surface)] text-[var(--on-dark-muted)]">Continue learning</Badge><span className="text-xs text-[var(--on-dark-subtle)]">{data.continueLearning.moduleTitle}</span></div><div className="mt-auto max-w-lg"><h2 className="mt-2 text-3xl font-semibold tracking-[-.045em] md:text-[38px]">{data.continueLearning.title}</h2></div><div className="mt-7 flex items-center gap-5"><div className="flex-1"><Progress value={data.continueLearning.progress * 100} label={`${data.continueLearning.title} progress`} className="bg-[var(--on-dark-surface)] [&>div]:bg-white"/><p className="mt-2 text-[10px] text-[var(--on-dark-subtle)]">{Math.round(data.continueLearning.progress * 100)}% complete</p></div><span className="grid size-11 place-items-center rounded-full bg-white text-[var(--ink)] transition group-hover:translate-x-1"><ArrowRight className="size-4"/></span></div></div></Link>}<Card><CardContent className="flex h-full min-h-[260px] flex-col p-6 md:p-7"><div className="flex items-start justify-between"><span className="grid size-11 place-items-center rounded-2xl bg-[var(--blue-soft)] text-[var(--blue)]"><Target className="size-5"/></span><span className="text-xs font-bold text-[var(--blue)]">10 questions</span></div><div className="mt-auto"><p className="text-[10px] font-bold uppercase tracking-[.14em] text-[var(--blue)]">Today’s focus</p><h2 className="mt-2 text-xl font-semibold tracking-[-.03em]">{focus?.title ?? "Mixed retention"}</h2><p className="mt-2 text-sm leading-6 text-[var(--ink-soft)]">{focus ? `${focus.mastery}% current mastery. Practice will prioritize this gap without repeating recent items.` : "Build more attempt history to unlock a focused recommendation."}</p><Button asChild variant="soft" size="sm" className="mt-5"><Link href={focus ? `/practice?topic=${focus.slug}&source=dashboard` : "/practice?source=dashboard"}>Start focused set <ChevronRight className="size-3.5"/></Link></Button></div></CardContent></Card></div>;
}

function Stat({ icon: Icon, value, label, detail }: { icon: typeof Flame; value: string; label: string; detail: string }) { return <Card><CardContent className="p-4 md:p-5"><div className="flex items-start justify-between"><Icon className="size-4 text-[var(--blue)]"/><span className="text-right text-[9px] text-[var(--ink-faint)]">{detail}</span></div><p className="mt-5 text-2xl font-bold tracking-[-.045em]">{value}</p><p className="mt-1 text-[11px] text-[var(--ink-soft)]">{label}</p></CardContent></Card>; }
function PlanRow({ status, title, detail, href, primary = false }: { status: string; title: string; detail: string; href: string; primary?: boolean }) { return <Link href={href} className="group flex items-center gap-4 rounded-2xl p-4 hover:bg-[var(--surface)]"><span className={`grid size-10 place-items-center rounded-xl ${primary ? "bg-[var(--blue)] text-white" : "bg-[var(--surface)] text-[var(--ink-soft)]"}`}><BookOpen className="size-4"/></span><div className="min-w-0 flex-1"><p className="text-[10px] font-bold uppercase tracking-[.12em] text-[var(--ink-faint)]">{status}</p><p className="mt-0.5 truncate text-sm font-semibold">{title}</p></div><p className="hidden text-xs text-[var(--ink-faint)] sm:block">{detail}</p><ChevronRight className="size-4 text-[var(--ink-faint)] transition group-hover:translate-x-0.5 group-hover:text-[var(--blue)]"/></Link>; }
