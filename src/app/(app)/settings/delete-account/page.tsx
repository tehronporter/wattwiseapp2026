import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { DeleteAccountForm } from "@/components/delete-account-form";

export const metadata: Metadata = { title: "Delete account" };

export default function DeleteAccountPage() {
  return (
    <div className="mx-auto max-w-xl px-4 py-10 md:px-8 md:py-16">
      <Link href="/settings" className="inline-flex items-center gap-2 text-xs font-semibold text-[var(--ink-soft)]"><ArrowLeft className="size-3.5"/>Back to settings</Link>
      <div className="mt-7 rounded-[24px] border border-[var(--line)] bg-white p-6 md:p-8">
        <p className="text-[10px] font-bold uppercase tracking-[.14em] text-[var(--error)]">Destructive action</p>
        <h1 className="mt-2 text-3xl font-bold tracking-[-.05em]">Delete your WattWise account?</h1>
        <p className="mt-4 text-sm leading-6 text-[var(--ink-soft)]">This permanently removes your profile, lesson progress, quiz attempts, tutor conversations, subscription mirror, and saved preferences. Store purchases remain in your Apple or Stripe account records as required by those providers.</p>
        <DeleteAccountForm />
      </div>
    </div>
  );
}

