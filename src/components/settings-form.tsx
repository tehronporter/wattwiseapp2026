"use client";

import { useActionState } from "react";
import { Bell, CalendarDays, Clock3, MapPin, Save, UserRound } from "lucide-react";
import { updateProfile, type ProfileFormState } from "@/app/actions/profile";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { jurisdictions } from "@/lib/jurisdictions";
import type { Viewer } from "@/lib/viewer";

const initialState: ProfileFormState = {};

export function SettingsForm({ viewer, reminderTime }: { viewer: Viewer; reminderTime: string }) {
  const [state, action, pending] = useActionState(updateProfile, initialState);
  const inputClass = "mt-2 h-11 w-full rounded-xl border border-[var(--line-strong)] bg-white px-3 text-sm outline-none focus:border-[var(--blue)] focus:ring-2 focus:ring-[var(--blue-soft)]";

  return (
    <form action={action} className="space-y-6">
      <Card>
        <CardContent>
          <SectionHeading icon={UserRound} title="Profile" description="The name shown across your WattWise account." />
          <label className="mt-5 block text-xs font-semibold" htmlFor="displayName">Display name<input className={inputClass} id="displayName" name="displayName" defaultValue={viewer.fullName} required /></label>
          <p className="mt-3 text-xs text-[var(--ink-soft)]">Email: {viewer.email}</p>
        </CardContent>
      </Card>

      <Card id="exam-plan">
        <CardContent>
          <SectionHeading icon={CalendarDays} title="Exam & study plan" description="Changes here immediately reframe your recommended pace." />
          <div className="mt-5 grid gap-4 sm:grid-cols-2">
            <label className="text-xs font-semibold" htmlFor="track">License track<select className={inputClass} id="track" name="track" defaultValue={viewer.track}><option value="apprentice">Apprentice</option><option value="journeyman">Journeyman</option><option value="master">Master</option></select></label>
            <label className="text-xs font-semibold" htmlFor="jurisdiction"><span className="flex items-center gap-1"><MapPin className="size-3.5"/>Jurisdiction</span><select className={inputClass} id="jurisdiction" name="jurisdiction" defaultValue={viewer.jurisdictionCode || "CA"}>{jurisdictions.map(([code, name]) => <option key={code} value={code}>{name}</option>)}</select></label>
            <label className="text-xs font-semibold" htmlFor="examDate">Exam date<input className={inputClass} id="examDate" name="examDate" type="date" defaultValue={viewer.examDate ?? ""} /></label>
            <label className="text-xs font-semibold" htmlFor="dailyGoal"><span className="flex items-center gap-1"><Clock3 className="size-3.5"/>Daily goal</span><select className={inputClass} id="dailyGoal" name="dailyGoal" defaultValue={String(viewer.dailyGoalMinutes)}><option value="15">15 minutes</option><option value="30">30 minutes</option><option value="45">45 minutes</option><option value="60">60 minutes</option></select></label>
          </div>
          <input type="hidden" name="timezone" value={viewer.timezone} />
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <SectionHeading icon={Bell} title="Notifications" description="Choose an optional local study reminder time." />
          <label className="mt-5 block text-xs font-semibold" htmlFor="reminderTime">Study reminder<input className={inputClass} id="reminderTime" name="reminderTime" type="time" defaultValue={reminderTime} /></label>
        </CardContent>
      </Card>

      <div className="flex items-center justify-between gap-4">
        <p role="status" className={`text-xs ${state.success ? "text-[var(--success)]" : "text-[var(--error)]"}`}>{state.message}</p>
        <Button type="submit" disabled={pending}><Save className="size-4"/>{pending ? "Saving…" : "Save changes"}</Button>
      </div>
    </form>
  );
}

function SectionHeading({ icon: Icon, title, description }: { icon: typeof UserRound; title: string; description: string }) {
  return <div className="flex items-start gap-3"><span className="grid size-10 shrink-0 place-items-center rounded-xl bg-[var(--blue-soft)] text-[var(--blue)]"><Icon className="size-4"/></span><div><h2 className="text-sm font-semibold">{title}</h2><p className="mt-1 text-xs leading-5 text-[var(--ink-soft)]">{description}</p></div></div>;
}
