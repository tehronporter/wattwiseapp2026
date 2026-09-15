import Link from "next/link";
import { ArrowRight, BookOpen, Check, ChevronRight, CircleCheck, Search, ShieldCheck, Sparkles } from "lucide-react";
import { BrandMark } from "@/components/brand-mark";
import { Button } from "@/components/ui/button";

export default function LandingPage() {
  return (
    <div className="min-h-screen overflow-hidden bg-white">
      <header className="relative z-20 mx-auto flex h-20 max-w-7xl items-center justify-between px-5 md:px-8">
        <BrandMark />
        <nav className="hidden items-center gap-7 text-sm font-medium text-[var(--ink-soft)] md:flex">
          <a href="#method" className="hover:text-[var(--ink)]">How it works</a>
          <a href="#curriculum" className="hover:text-[var(--ink)]">Curriculum</a>
          <a href="#codebook" className="hover:text-[var(--ink)]">Codebook</a>
        </nav>
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" className="hidden sm:inline-flex"><Link href="/dashboard">Sign in</Link></Button>
          <Button asChild size="sm"><Link href="/dashboard">Start studying <ArrowRight className="size-3.5" /></Link></Button>
        </div>
      </header>

      <main>
        <section className="relative px-5 pb-20 pt-16 md:px-8 md:pb-28 md:pt-24">
          <div className="page-grid pointer-events-none absolute inset-0" />
          <div className="relative mx-auto max-w-7xl">
            <div className="mx-auto max-w-3xl text-center">
              <div className="animate-rise mx-auto mb-7 inline-flex items-center gap-2 rounded-full border border-[var(--line)] bg-white px-3 py-1.5 text-[11px] font-semibold text-[var(--ink-soft)] shadow-sm">
                <span className="size-1.5 rounded-full bg-[var(--blue)]" /> Built for the 2026 NEC cycle
              </div>
              <h1 className="animate-rise delay-1 text-balance text-[48px] font-bold leading-[.98] tracking-[-.065em] text-[var(--ink)] sm:text-[64px] md:text-[78px]">
                Know the code.<br /><span className="text-[var(--blue)]">Pass with confidence.</span>
              </h1>
              <p className="animate-rise delay-2 mx-auto mt-7 max-w-2xl text-balance text-base leading-7 text-[var(--ink-soft)] md:text-lg">
                A clear, personalized study system for electrician licensing exams—grounded in the NEC and designed around how you actually learn.
              </p>
              <div className="animate-rise delay-2 mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
                <Button asChild size="lg"><Link href="/dashboard">Open your study plan <ArrowRight className="size-4" /></Link></Button>
                <Button asChild size="lg" variant="secondary"><Link href="/practice">Try a practice set</Link></Button>
              </div>
              <p className="mt-5 text-xs text-[var(--ink-faint)]">No credit card · Your progress stays yours</p>
            </div>

            <div className="relative mx-auto mt-16 max-w-5xl rounded-[30px] border border-[var(--line)] bg-white p-2 shadow-[0_32px_100px_rgba(30,40,80,.12)] md:mt-20 md:p-3">
              <div className="grid min-h-[480px] overflow-hidden rounded-[22px] border border-[var(--line)] bg-[#fbfbfa] md:grid-cols-[190px_1fr]">
                <div className="hidden border-r border-[var(--line)] bg-white p-5 md:block">
                  <BrandMark />
                  <div className="mt-9 space-y-2 text-xs font-medium text-[var(--ink-soft)]">
                    {['Overview','Learn','Practice','Review','Codebook'].map((label, index) => <div key={label} className={`rounded-lg px-3 py-2.5 ${index === 0 ? 'bg-[var(--blue-soft)] text-[var(--blue)]' : ''}`}>{label}</div>)}
                  </div>
                </div>
                <div className="p-5 md:p-8">
                  <div className="flex items-start justify-between"><div><p className="text-[11px] font-semibold text-[var(--blue)]">TUESDAY · STUDY DAY 12</p><h2 className="mt-2 text-2xl font-bold tracking-[-.04em]">Good morning, Tehron.</h2><p className="mt-1 text-sm text-[var(--ink-soft)]">One focused session moves you closer.</p></div><div className="hidden rounded-xl border border-[var(--line)] bg-white px-3 py-2 text-right sm:block"><p className="text-[10px] text-[var(--ink-faint)]">EXAM IN</p><p className="text-sm font-bold">68 days</p></div></div>
                  <div className="mt-7 grid gap-4 lg:grid-cols-[1.4fr_.8fr]">
                    <div className="rounded-[20px] bg-[var(--ink)] p-6 text-white"><p className="text-[10px] font-semibold tracking-[.12em] text-white/55">CONTINUE LEARNING</p><h3 className="mt-8 text-2xl font-semibold tracking-[-.04em]">Power, energy & Watt’s law</h3><p className="mt-2 text-xs leading-5 text-white/60">Electrical theory · Lesson 2 of 4</p><div className="mt-6 h-1 rounded-full bg-white/15"><div className="h-full w-[62%] rounded-full bg-white" /></div><div className="mt-5 inline-flex items-center gap-2 text-xs font-semibold">Resume lesson <ChevronRight className="size-3" /></div></div>
                    <div className="rounded-[20px] border border-[var(--line)] bg-white p-5"><div className="flex items-center justify-between"><span className="grid size-9 place-items-center rounded-xl bg-[var(--blue-soft)] text-[var(--blue)]"><Sparkles className="size-4" /></span><span className="text-xs font-semibold text-[var(--blue)]">12 min</span></div><h3 className="mt-8 font-semibold">Today’s focus</h3><p className="mt-2 text-xs leading-5 text-[var(--ink-soft)]">Review grounding paths based on your last practice set.</p></div>
                  </div>
                  <div className="mt-4 grid grid-cols-3 gap-3">{[['72%','Course'],['8 days','Streak'],['84%','Accuracy']].map(([value,label]) => <div key={label} className="rounded-2xl border border-[var(--line)] bg-white p-4"><p className="text-lg font-bold tracking-[-.04em]">{value}</p><p className="mt-1 text-[10px] text-[var(--ink-faint)]">{label}</p></div>)}</div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section id="method" className="bg-[var(--ink)] px-5 py-24 text-white md:px-8 md:py-32">
          <div className="mx-auto max-w-7xl">
            <div className="max-w-2xl"><p className="text-xs font-semibold uppercase tracking-[.16em] text-white/45">A study system, not a content dump</p><h2 className="mt-5 text-balance text-4xl font-bold leading-tight tracking-[-.055em] md:text-5xl">Everything points to the next right thing.</h2></div>
            <div className="mt-16 grid gap-px overflow-hidden rounded-[24px] border border-white/10 bg-white/10 md:grid-cols-3">
              {[{n:'01',icon:BookOpen,title:'Learn the concept',copy:'Short, structured lessons connect theory, code language, and the jobsite.'},{n:'02',icon:CircleCheck,title:'Prove you know it',copy:'Targeted questions adapt to weak topics without repeating what you’ve mastered.'},{n:'03',icon:Sparkles,title:'Understand the miss',copy:'Get a direct explanation with the governing code path—not a generic answer.'}].map((item) => <div key={item.n} className="bg-[var(--ink)] p-7 md:p-9"><div className="flex items-center justify-between"><item.icon className="size-5 text-[#8ba0ff]"/><span className="text-xs text-white/30">{item.n}</span></div><h3 className="mt-16 text-xl font-semibold">{item.title}</h3><p className="mt-3 text-sm leading-6 text-white/55">{item.copy}</p></div>)}
            </div>
          </div>
        </section>

        <section id="curriculum" className="px-5 py-24 md:px-8 md:py-32">
          <div className="mx-auto grid max-w-7xl gap-14 lg:grid-cols-[.8fr_1.2fr] lg:items-center">
            <div><p className="text-xs font-bold uppercase tracking-[.16em] text-[var(--blue)]">Your path, made clear</p><h2 className="mt-5 text-4xl font-bold leading-[1.05] tracking-[-.055em] md:text-5xl">Built around your license, state, and timeline.</h2><p className="mt-6 max-w-lg text-base leading-7 text-[var(--ink-soft)]">WattWise turns a massive exam outline into focused daily work. You always know what matters, why it matters, and what to do next.</p><div className="mt-8 space-y-3">{['Apprentice, journeyman, and master tracks','Jurisdiction-aware exam guidance','Readiness based on demonstrated mastery'].map(item => <p key={item} className="flex items-center gap-3 text-sm font-medium"><Check className="size-4 text-[var(--blue)]" />{item}</p>)}</div></div>
            <div className="rounded-[28px] bg-[var(--surface)] p-4 md:p-7">{['Electrical theory','Navigate the NEC','Wiring methods','Branch circuits'].map((item,index) => <div key={item} className="mb-3 flex items-center gap-4 rounded-2xl bg-white p-4 last:mb-0"><span className={`grid size-10 place-items-center rounded-xl text-xs font-bold ${index < 2 ? 'bg-[var(--blue)] text-white' : 'bg-[var(--surface)] text-[var(--ink-faint)]'}`}>{String(index+1).padStart(2,'0')}</span><div className="flex-1"><div className="flex justify-between text-sm font-semibold"><span>{item}</span><span className="text-xs text-[var(--ink-faint)]">{[72,38,12,0][index]}%</span></div><div className="mt-2 h-1 rounded-full bg-[var(--line)]"><div className="h-full rounded-full bg-[var(--blue)]" style={{width:`${[72,38,12,0][index]}%`}} /></div></div></div>)}</div>
          </div>
        </section>

        <section id="codebook" className="px-5 pb-24 md:px-8 md:pb-32">
          <div className="mx-auto max-w-7xl overflow-hidden rounded-[32px] bg-[var(--blue)] px-6 py-14 text-white md:px-14 md:py-16">
            <div className="grid gap-10 md:grid-cols-[1fr_.8fr] md:items-center"><div><ShieldCheck className="size-7 text-white/80"/><h2 className="mt-6 max-w-xl text-4xl font-bold tracking-[-.055em] md:text-5xl">The Code is complex. Finding your answer shouldn’t be.</h2><p className="mt-5 max-w-xl text-sm leading-6 text-white/70">Search by article, concept, or plain language. Follow the code path, see a simpler explanation, then practice it in context.</p></div><div className="rounded-[22px] bg-white p-3 text-[var(--ink)] shadow-2xl"><div className="flex items-center gap-3 rounded-2xl bg-[var(--surface)] px-4 py-3"><Search className="size-4 text-[var(--ink-faint)]"/><span className="text-sm text-[var(--ink-soft)]">grounding electrode conductor</span></div><div className="p-4"><p className="text-xs font-bold text-[var(--blue)]">ARTICLE 250</p><p className="mt-2 font-semibold">Grounding and bonding</p><p className="mt-2 text-xs leading-5 text-[var(--ink-soft)]">System grounding, equipment bonding, electrodes, and effective fault-current paths.</p></div></div></div>
          </div>
        </section>

        <section className="border-t border-[var(--line)] px-5 py-24 text-center md:px-8"><p className="text-xs font-bold uppercase tracking-[.15em] text-[var(--blue)]">Your next study session is ready</p><h2 className="mx-auto mt-5 max-w-2xl text-balance text-4xl font-bold tracking-[-.055em] md:text-5xl">Start with a clear plan. Finish with real confidence.</h2><Button asChild size="lg" className="mt-8"><Link href="/dashboard">Start studying <ArrowRight className="size-4" /></Link></Button></section>
      </main>
      <footer className="border-t border-[var(--line)] px-5 py-8 md:px-8"><div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-4 sm:flex-row"><BrandMark/><p className="text-xs text-[var(--ink-faint)]">Educational preparation. Always verify adopted code and local amendments.</p></div></footer>
    </div>
  );
}
