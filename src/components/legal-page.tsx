import Link from "next/link";
import { BrandMark } from "@/components/brand-mark";

export function LegalPage({ title, updated = "September 20, 2026", children }: { title: string; updated?: string; children: React.ReactNode }) {
  return <main className="min-h-screen bg-white px-5 py-10"><article className="mx-auto max-w-3xl"><Link href="/"><BrandMark/></Link><p className="mt-14 text-xs font-bold uppercase tracking-[.14em] text-[var(--blue)]">WattWise policies</p><h1 className="mt-3 text-4xl font-bold tracking-[-.05em]">{title}</h1><p className="mt-2 text-xs text-[var(--ink-faint)]">Last updated {updated}</p><div className="prose-wattwise mt-10 space-y-7 text-sm leading-7 text-[var(--ink-soft)]">{children}</div><nav className="mt-12 flex flex-wrap gap-4 border-t border-[var(--line)] pt-6 text-xs"><Link href="/terms">Terms</Link><Link href="/privacy">Privacy</Link><Link href="/refund-policy">Refunds</Link><Link href="/support">Support</Link></nav></article></main>;
}
