import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, Bot, ChevronRight, CircleAlert, Clock3, TrendingUp } from "lucide-react";
import { LabProgress } from "@/components/labs/progress";
import { PageHeading } from "@/components/page-heading";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { getReviewData } from "@/lib/review-data";
import { getViewer } from "@/lib/viewer";

export const metadata: Metadata = { title: "Review", description: "Review missed questions, weak topics, and recent practice results." };

export default async function ReviewPage() {
  const viewer = await getViewer();
  if (!viewer) return null;
  const data = await getReviewData(viewer);
  return (
    <div className="mx-auto max-w-[1120px] px-4 py-8 md:px-8 md:py-10 lg:px-10">
      <PageHeading eyebrow="Performance center" title="Turn misses into mastery" description="Review the exact questions you missed, then practice the topics that will improve readiness fastest."/>
      <LabProgress />
      <div className="mt-8 grid gap-4 md:grid-cols-3">
        <Metric label="Overall accuracy" value={data.accuracy === null ? "—" : `${data.accuracy}%`} detail={data.accuracy === null ? "Complete your first set" : "Across recent attempts"} trend />
        <Metric label="Questions to review" value={String(data.misses.length)} detail={data.misses.length ? "Incorrect answers shown below" : "No misses yet"} />
        <Metric label="Readiness score" value={data.readiness === null ? "—" : `${data.readiness}%`} detail={data.readiness === null ? "Unlocks after 10 answers" : "55% accuracy · 25% lessons · 20% mastery"} />
      </div>

      <div className="mt-9 grid gap-8 lg:grid-cols-[1.25fr_.75fr]">
        <section>
          <div className="mb-4 flex items-center justify-between"><h2 className="text-lg font-semibold tracking-[-.03em]">Focus areas</h2><Button asChild size="sm"><Link href="/practice?source=review">Practice all <ArrowRight className="size-3.5"/></Link></Button></div>
          {data.focusAreas.length ? <Card><CardContent className="p-2">{data.focusAreas.map((area) => <div key={area.slug} className="flex flex-col gap-4 rounded-2xl p-4 hover:bg-[var(--surface)] sm:flex-row sm:items-center"><span className="grid size-10 shrink-0 place-items-center rounded-xl bg-[var(--error-soft)] text-[var(--error)]"><CircleAlert className="size-4"/></span><div className="min-w-0 flex-1"><div className="flex justify-between"><p className="text-sm font-semibold">{area.title}</p><b className="text-xs">{area.mastery}% mastery</b></div><p className="mt-1 text-[11px] text-[var(--ink-soft)]">{area.misses} recent miss{area.misses === 1 ? "" : "es"}</p><div className="mt-2 h-1 rounded-full bg-[var(--line)]" role="progressbar" aria-label={`${area.title} mastery`} aria-valuenow={area.mastery} aria-valuemin={0} aria-valuemax={100}><div className="h-full rounded-full bg-[var(--blue)]" style={{ width: `${area.mastery}%` }}/></div></div><div className="flex items-center gap-2"><Link href={`/tutor?prompt=${encodeURIComponent(`Help me review ${area.title}`)}`} className="grid size-9 place-items-center rounded-full bg-[var(--blue-soft)] text-[var(--blue)]" aria-label={`Ask tutor about ${area.title}`}><Bot className="size-4"/></Link><Link href={`/practice?topic=${area.slug}&source=review`} aria-label={`Practice ${area.title}`} className="grid size-9 place-items-center rounded-full border border-[var(--line)]"><ChevronRight className="size-4"/></Link></div></div>)}</CardContent></Card> : <EmptyReview />}
        </section>
        <section><h2 className="mb-4 text-lg font-semibold tracking-[-.03em]">Recent sets</h2><Card><CardContent className="space-y-5">{data.recentSets.length ? data.recentSets.map((item) => <a href={`#attempt-${item.id}`} key={item.id} className="flex items-center gap-3 rounded-xl outline-none focus-visible:ring-2 focus-visible:ring-[var(--blue)]"><span className="grid size-9 place-items-center rounded-xl bg-[var(--surface)]"><Clock3 className="size-3.5 text-[var(--ink-soft)]"/></span><div className="min-w-0 flex-1"><p className="truncate text-xs font-semibold">Adaptive practice set</p><p className="mt-0.5 text-[10px] text-[var(--ink-faint)]">{item.date}</p></div><b className="text-xs">{item.score}</b></a>) : <p className="text-sm leading-6 text-[var(--ink-soft)]">Complete a practice set to build your history.</p>}</CardContent></Card></section>
      </div>

      <section className="mt-10"><h2 className="text-lg font-semibold tracking-[-.03em]">Missed questions</h2><div className="mt-4 space-y-3">{data.misses.length ? data.misses.map((miss, index) => <details id={`attempt-${miss.attemptId}`} key={`${miss.attemptId}-${miss.questionId}`} className="group rounded-2xl border border-[var(--line)] bg-white p-5"><summary className="cursor-pointer list-none pr-5 text-sm font-semibold marker:hidden"><span className="mr-2 text-[var(--ink-faint)]">{index + 1}.</span>{miss.question}<span className="ml-2 text-[10px] font-medium text-[var(--blue)]">{miss.topic}</span></summary><div className="mt-4 grid gap-3 border-t border-[var(--line)] pt-4 text-xs leading-5"><p><b>Your answer:</b> {miss.userAnswer}</p><p className="text-[var(--success)]"><b>Correct answer:</b> {miss.correctAnswer}</p><p className="text-[var(--ink-soft)]">{miss.explanation}</p>{miss.reference && <p className="font-semibold text-[var(--blue)]">{miss.reference}</p>}<div className="mt-2 flex gap-2"><Button asChild size="sm" variant="soft"><Link href={`/tutor?prompt=${encodeURIComponent(`Explain why the correct answer is ${miss.correctAnswer} for: ${miss.question}`)}`}>Ask tutor</Link></Button><Button asChild size="sm" variant="secondary"><Link href={`/practice?topic=${encodeURIComponent(miss.topic.toLowerCase().replace(/[^a-z0-9]+/g, "-"))}&source=missed-question`}>Practice topic</Link></Button></div></div></details>) : <p className="rounded-2xl border border-dashed border-[var(--line-strong)] p-6 text-sm text-[var(--ink-soft)]">No missed questions yet. Complete a practice set and explanations will appear here.</p>}</div></section>
    </div>
  );
}

function Metric({ label, value, detail, trend = false }: { label: string; value: string; detail: string; trend?: boolean }) { return <Card><CardContent><div className="flex items-center justify-between"><span className="text-[10px] font-semibold uppercase tracking-[.1em] text-[var(--ink-faint)]">{label}</span>{trend && <TrendingUp className="size-4 text-[var(--success)]"/>}</div><p className="mt-5 text-3xl font-bold tracking-[-.05em]">{value}</p><p className="mt-1 text-xs text-[var(--ink-soft)]">{detail}</p></CardContent></Card>; }
function EmptyReview() { return <Card><CardContent><h3 className="text-sm font-semibold">No focus areas yet</h3><p className="mt-2 text-xs leading-5 text-[var(--ink-soft)]">A placement set gives WattWise enough evidence to recommend your first weak-area review.</p><Button asChild size="sm" className="mt-4"><Link href="/practice?source=placement&count=10">Take placement set</Link></Button></CardContent></Card>; }

