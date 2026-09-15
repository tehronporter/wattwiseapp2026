import Link from "next/link";
import { ArrowLeft, ArrowRight, Bookmark, Bot, Check, Clock3 } from "lucide-react";
import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { lessonContent, modules } from "@/lib/content";

export function generateStaticParams() { return modules.flatMap((module) => module.lessons.map((lesson) => ({ module: module.slug, lesson: lesson.slug }))); }

export default async function LessonPage({ params }: { params: Promise<{ module: string; lesson: string }> }) {
  const { module: moduleSlug, lesson: lessonSlug } = await params;
  const courseModule = modules.find((item) => item.slug === moduleSlug);
  const lesson = courseModule?.lessons.find((item) => item.slug === lessonSlug);
  if (!courseModule || !lesson) notFound();
  const content = lessonSlug === lessonContent.slug ? lessonContent : { ...lessonContent, title: lesson.title, module: courseModule.title, duration: lesson.duration };
  return (
    <div className="min-h-[calc(100vh-68px)] bg-white">
      <div className="sticky top-[68px] z-20 border-b border-[var(--line)] bg-white/92 backdrop-blur-xl"><div className="mx-auto flex max-w-[1000px] items-center gap-4 px-4 py-3 md:px-8"><Link href={`/learn/${courseModule.slug}`} className="grid size-9 place-items-center rounded-full hover:bg-[var(--surface)]"><ArrowLeft className="size-4"/></Link><div className="min-w-0 flex-1"><p className="truncate text-xs font-semibold">{content.title}</p><Progress value={62} className="mt-1.5 max-w-[260px]"/></div><Button variant="ghost" size="icon" aria-label="Bookmark"><Bookmark className="size-4"/></Button><Badge className="hidden sm:inline-flex">8 min left</Badge></div></div>
      <article className="mx-auto max-w-[720px] px-5 py-12 md:py-16">
        <div className="flex items-center gap-3 text-xs text-[var(--ink-soft)]"><span>{content.module}</span><span>·</span><span className="flex items-center gap-1"><Clock3 className="size-3.5"/>{content.duration} min</span></div>
        <h1 className="mt-5 text-balance text-4xl font-bold leading-[1.04] tracking-[-.055em] md:text-[52px]">{content.title}</h1>
        <div className="mt-8 rounded-[20px] bg-[var(--surface)] p-5"><p className="text-[10px] font-bold uppercase tracking-[.14em] text-[var(--ink-faint)]">By the end, you can</p><ul className="mt-3 space-y-2">{content.objectives.map((item) => <li key={item} className="flex gap-3 text-sm leading-5"><Check className="mt-0.5 size-4 shrink-0 text-[var(--blue)]"/>{item}</li>)}</ul></div>
        <div className="mt-12 space-y-12">
          {content.sections.map((section,index) => <section key={section.title}><p className="text-[10px] font-bold uppercase tracking-[.15em] text-[var(--blue)]">{String(index+1).padStart(2,'0')}</p><h2 className="mt-3 text-2xl font-semibold tracking-[-.035em]">{section.title}</h2><p className="mt-4 text-[17px] leading-8 text-[#42464d]">{section.body}</p>{index===0&&<div className="mt-6 rounded-[18px] border border-[var(--line)] p-5 text-center"><p className="text-[11px] font-semibold uppercase tracking-[.12em] text-[var(--ink-faint)]">Watt’s law</p><p className="mt-3 text-3xl font-bold tracking-[-.04em]">P = V × I</p><p className="mt-2 text-xs text-[var(--ink-soft)]">watts = volts × amperes</p></div>}{index===1&&<Link href="/codebook?q=Article%20100" className="mt-6 flex items-center justify-between rounded-[18px] bg-[var(--blue-soft)] p-4 text-sm font-semibold text-[var(--blue)]"><span>Open related code context · Article 100</span><ArrowRight className="size-4"/></Link>}</section>)}
        </div>
        <div className="mt-14 rounded-[22px] bg-[var(--ink)] p-6 text-white"><div className="flex items-start gap-4"><span className="grid size-10 shrink-0 place-items-center rounded-xl bg-white/10 text-[#9aabff]"><Bot className="size-5"/></span><div><p className="font-semibold">Need another angle?</p><p className="mt-1 text-sm leading-6 text-white/55">Ask the tutor to explain this lesson with a jobsite example or walk through a calculation.</p><Button asChild variant="secondary" size="sm" className="mt-4 border-white/15 bg-white text-[var(--ink)]"><Link href={`/tutor?prompt=${encodeURIComponent(`Explain ${content.title} with a jobsite example`)}`}>Ask about this lesson <ArrowRight className="size-3.5"/></Link></Button></div></div></div>
        <div className="mt-8 flex items-center justify-between border-t border-[var(--line)] pt-7"><Button variant="ghost"><ArrowLeft className="size-4"/>Previous</Button><Button asChild><Link href="/practice">Check your understanding <ArrowRight className="size-4"/></Link></Button></div>
      </article>
    </div>
  );
}
