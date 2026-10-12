"use client";

import { useActionState, useMemo, useState } from "react";
import { ArrowLeft, ArrowRight, CalendarDays, Check, Clock3, MapPin } from "lucide-react";
import { completeOnboarding, type ProfileFormState } from "@/app/actions/profile";
import { BrandMark } from "@/components/brand-mark";
import { Button } from "@/components/ui/button";
import { jurisdictions } from "@/lib/jurisdictions";

const initialState: ProfileFormState = {};

export function OnboardingFlow() {
  const [state, action, pending] = useActionState(completeOnboarding, initialState);
  const [step, setStep] = useState(0);
  const [track, setTrack] = useState("journeyman");
  const [jurisdiction, setJurisdiction] = useState("CA");
  const [examDate, setExamDate] = useState("");
  const [dailyGoal, setDailyGoal] = useState("30");
  const timezone = useMemo(() => Intl.DateTimeFormat().resolvedOptions().timeZone || "America/Los_Angeles", []);
  const steps = ["License track", "Jurisdiction", "Exam date", "Daily goal"];

  return (
    <main className="min-h-screen bg-[var(--surface-warm)] px-4 py-8">
      <div className="mx-auto max-w-2xl">
        <BrandMark />
        <div className="mt-8 flex gap-2" aria-label={`Step ${step + 1} of ${steps.length}`}>
          {steps.map((label, index) => (
            <span key={label} className={`h-1.5 flex-1 rounded-full ${index <= step ? "bg-[var(--blue)]" : "bg-[var(--line)]"}`} />
          ))}
        </div>

        <form action={action} className="mt-5 rounded-[28px] border border-[var(--line)] bg-white p-6 sm:p-9">
          <input type="hidden" name="track" value={track} />
          <input type="hidden" name="jurisdiction" value={jurisdiction} />
          <input type="hidden" name="examDate" value={examDate} />
          <input type="hidden" name="dailyGoal" value={dailyGoal} />
          <input type="hidden" name="reminderTime" value="" />
          <input type="hidden" name="timezone" value={timezone} />

          <p className="text-[10px] font-bold uppercase tracking-[.14em] text-[var(--blue)]">{steps[step]}</p>
          {step === 0 && (
            <Step title="Which exam are you preparing for?" description="This controls curriculum weighting and practice difficulty.">
              <div className="grid gap-3 sm:grid-cols-3">
                {["apprentice", "journeyman", "master"].map((value) => <Choice key={value} active={track === value} onClick={() => setTrack(value)}>{titleCase(value)}</Choice>)}
              </div>
            </Step>
          )}
          {step === 1 && (
            <Step title="Where will you take the exam?" description="We’ll show the adopted code cycle and verified state guidance where available.">
              <label className="block text-xs font-semibold" htmlFor="jurisdiction-choice">Jurisdiction</label>
              <div className="relative mt-2"><MapPin className="pointer-events-none absolute left-3 top-3.5 size-4 text-[var(--ink-faint)]"/><select id="jurisdiction-choice" value={jurisdiction} onChange={(event) => setJurisdiction(event.target.value)} className="h-11 w-full rounded-xl border border-[var(--line-strong)] bg-white pl-10 pr-3 text-sm outline-none focus:ring-2 focus:ring-[var(--blue-soft)]">{jurisdictions.map(([code, name]) => <option key={code} value={code}>{name}</option>)}</select></div>
            </Step>
          )}
          {step === 2 && (
            <Step title="When is your exam?" description="Optional. WattWise uses this to calculate daily pace, never to predict a guaranteed result.">
              <label className="block text-xs font-semibold" htmlFor="exam-date">Exam date</label>
              <div className="relative mt-2"><CalendarDays className="pointer-events-none absolute left-3 top-3.5 size-4 text-[var(--ink-faint)]"/><input id="exam-date" type="date" value={examDate} min={new Date().toISOString().slice(0, 10)} onChange={(event) => setExamDate(event.target.value)} className="h-11 w-full rounded-xl border border-[var(--line-strong)] pl-10 pr-3 text-sm outline-none focus:ring-2 focus:ring-[var(--blue-soft)]" /></div>
              <button type="button" onClick={() => setExamDate("")} className="mt-3 text-xs font-semibold text-[var(--blue)]">My exam isn’t scheduled yet</button>
            </Step>
          )}
          {step === 3 && (
            <Step title="Choose a sustainable daily goal." description="You can change this at any time in Settings.">
              <div className="grid gap-3 sm:grid-cols-3">
                {["15", "30", "45"].map((value) => <Choice key={value} active={dailyGoal === value} onClick={() => setDailyGoal(value)}><Clock3 className="size-4" />{value} minutes</Choice>)}
              </div>
              <div className="mt-6 rounded-2xl bg-[var(--blue-soft)] p-4 text-sm text-[var(--blue)]"><Check className="mr-2 inline size-4"/>Your first plan will be generated from these answers.</div>
            </Step>
          )}

          {state.message && <p role="alert" className="mt-5 rounded-xl bg-[var(--error-soft)] px-3 py-2 text-xs text-[var(--error)]">{state.message}</p>}
          <div className="mt-8 flex items-center justify-between">
            <Button type="button" variant="ghost" disabled={step === 0 || pending} onClick={() => setStep((value) => value - 1)}><ArrowLeft className="size-4"/>Back</Button>
            {step < steps.length - 1 ? (
              <Button type="button" onClick={() => setStep((value) => value + 1)}>Continue<ArrowRight className="size-4"/></Button>
            ) : (
              <Button type="submit" disabled={pending}>{pending ? "Building plan…" : "Build my plan"}<ArrowRight className="size-4"/></Button>
            )}
          </div>
        </form>
      </div>
    </main>
  );
}

function Step({ title, description, children }: { title: string; description: string; children: React.ReactNode }) {
  return <div><h1 className="mt-2 text-3xl font-bold tracking-[-.05em]">{title}</h1><p className="mt-3 text-sm leading-6 text-[var(--ink-soft)]">{description}</p><div className="mt-7">{children}</div></div>;
}

function Choice({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return <button type="button" aria-pressed={active} onClick={onClick} className={`flex min-h-20 items-center justify-center gap-2 rounded-2xl border px-4 text-sm font-semibold outline-none focus-visible:ring-2 focus-visible:ring-[var(--blue)] ${active ? "border-[var(--blue)] bg-[var(--blue-soft)] text-[var(--blue)]" : "border-[var(--line)] bg-white hover:border-[var(--line-strong)]"}`}>{children}</button>;
}

function titleCase(value: string) { return `${value[0].toUpperCase()}${value.slice(1)}`; }

