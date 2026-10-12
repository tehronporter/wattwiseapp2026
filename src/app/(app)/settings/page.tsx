import type { Metadata } from "next";
import Link from "next/link";
import { CreditCard, Download, LogOut, Shield, Trash2 } from "lucide-react";
import { signOut } from "@/app/actions/auth";
import { PageHeading } from "@/components/page-heading";
import { SettingsForm } from "@/components/settings-form";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/viewer";

export const metadata: Metadata = { title: "Settings", description: "Manage your WattWise profile, exam plan, reminders, and data." };

export default async function SettingsPage() {
  const viewer = await getViewer();
  if (!viewer) return null;
  let reminderTime = "";
  let plan = "Preview";
  if (!viewer.isDemo) {
    const supabase = await createClient();
    const [{ data: preferences }, { data: subscription }] = await Promise.all([
      supabase.from("study_preferences").select("preferred_reminder_time").eq("user_id", viewer.id).maybeSingle(),
      supabase.from("subscriptions").select("tier, status, expires_at").eq("user_id", viewer.id).maybeSingle(),
    ]);
    reminderTime = preferences?.preferred_reminder_time?.slice(0, 5) ?? "";
    const active = subscription?.status === "active";
    if (active && subscription?.tier === "fast_track") plan = "Fast Track";
    if (active && subscription?.tier === "full_prep") plan = "Full Prep";
  }

  return (
    <div className="mx-auto max-w-[900px] px-4 py-8 md:px-8 md:py-10 lg:px-10">
      <PageHeading eyebrow="Account" title="Settings" description="Keep your profile and study plan aligned with your real exam timeline." />
      <div className="mt-8"><SettingsForm viewer={viewer} reminderTime={reminderTime} /></div>
      <Card className="mt-6"><CardContent><div className="flex items-start gap-3"><span className="grid size-10 shrink-0 place-items-center rounded-xl bg-[var(--blue-soft)] text-[var(--blue)]"><CreditCard className="size-4"/></span><div className="flex-1"><h2 className="text-sm font-semibold">Plan & access</h2><p className="mt-1 text-xs leading-5 text-[var(--ink-soft)]">Current plan: {plan}. Paid web plans are coming soon.</p></div><Button asChild size="sm" variant="secondary"><Link href="/pricing">View plans</Link></Button></div></CardContent></Card>
      <Card className="mt-6">
        <CardContent>
          <div className="flex items-start gap-3"><span className="grid size-10 shrink-0 place-items-center rounded-xl bg-[var(--surface)] text-[var(--ink-soft)]"><Shield className="size-4"/></span><div><h2 className="text-sm font-semibold">Privacy & data</h2><p className="mt-1 text-xs leading-5 text-[var(--ink-soft)]">Export your study data or permanently delete your account.</p></div></div>
          <div className="mt-5 flex flex-wrap gap-3"><Button asChild variant="secondary" size="sm"><a href="/api/account/export"><Download className="size-3.5"/>Export data</a></Button><Button asChild variant="ghost" size="sm" className="text-[var(--error)]"><a href="/settings/delete-account"><Trash2 className="size-3.5"/>Delete account</a></Button></div>
        </CardContent>
      </Card>
      <form action={signOut} className="mt-6"><Button type="submit" variant="ghost" className="text-[var(--error)]"><LogOut className="size-4"/>Sign out</Button></form>
    </div>
  );
}
