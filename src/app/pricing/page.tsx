import type { Metadata } from "next";
import Link from "next/link";
import { Check } from "lucide-react";
import { BrandMark } from "@/components/brand-mark";
import { Button } from "@/components/ui/button";

export const metadata: Metadata = { title: "Pricing", description: "Choose a WattWise electrician exam-prep access plan." };
const features = ["Complete lesson and practice library", "Adaptive review and readiness tracking", "Code-aware AI tutor", "Jurisdiction-aware code guidance"];

export default function PricingPage() {
  return <main className="min-h-screen bg-[var(--surface)] px-5 py-10 md:py-16"><div className="mx-auto max-w-5xl"><Link href="/"><BrandMark/></Link><div className="mx-auto mt-16 max-w-2xl text-center"><p className="text-xs font-bold uppercase tracking-[.15em] text-[var(--blue)]">Simple access</p><h1 className="mt-4 text-4xl font-bold tracking-[-.055em] md:text-5xl">Choose the runway to your exam.</h1><p className="mt-5 text-sm leading-6 text-[var(--ink-soft)]">Start with the preview. Upgrade once for access through the study period—no automatic renewal.</p></div><div className="mt-12 grid gap-5 md:grid-cols-3">
    <Plan name="Preview" price="$0" detail="Try the study system" action={<Button asChild variant="secondary" className="w-full"><Link href="/sign-up">Start preview</Link></Button>}/>
    <Plan name="Fast Track" price="$79" detail="3 months of full access" featured action={<Button disabled className="w-full">Coming soon</Button>}/>
    <Plan name="Full Prep" price="$149" detail="12 months of full access" action={<Button disabled className="w-full">Coming soon</Button>}/>
  </div><p className="mt-8 text-center text-xs text-[var(--ink-faint)]">Paid web plans are not available yet. See the <Link className="underline" href="/refund-policy">refund policy</Link>.</p></div></main>;
}

function Plan({ name, price, detail, action, featured = false }: { name: string; price: string; detail: string; action: React.ReactNode; featured?: boolean }) { return <section className={`rounded-[24px] border bg-white p-6 ${featured ? "border-[var(--blue)] shadow-[0_20px_60px_rgba(28,67,255,.12)]" : "border-[var(--line)]"}`}>{featured && <p className="mb-4 text-[10px] font-bold uppercase tracking-[.14em] text-[var(--blue)]">Most focused</p>}<h2 className="text-lg font-semibold">{name}</h2><p className="mt-5 text-4xl font-bold tracking-[-.05em]">{price}</p><p className="mt-2 text-xs text-[var(--ink-soft)]">{detail}</p><ul className="my-7 space-y-3">{features.map((feature) => <li key={feature} className="flex gap-2 text-xs leading-5"><Check className="mt-0.5 size-3.5 shrink-0 text-[var(--blue)]"/>{feature}</li>)}</ul>{action}</section>; }
