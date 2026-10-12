import Link from "next/link";
import { LabProgress } from "@/components/labs/progress";
import { labs } from "@/lib/labs";

export const metadata = { title: "Interactive labs | WattWise" };

export default function LabsPage() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-10 md:px-8">
      <p className="text-xs font-bold uppercase tracking-[.18em] text-[var(--blue)]">WattWise / Applied learning</p>
      <h1 className="mt-3 text-4xl font-semibold tracking-tight">Learn by working it out.</h1>
      <p className="mt-3 max-w-2xl text-[var(--ink-soft)]">Interactive concept trainers make electrical relationships visible before you apply them in worked calculations, code lookup, supervised practice, or the field.</p>
      <div className="mt-5 max-w-3xl rounded-2xl border border-[var(--line)] bg-[var(--surface)] p-4 text-xs leading-5 text-[var(--ink-soft)]">
        <b className="text-[var(--ink)]">What these are:</b> simplified exam-prep models. They do not reproduce an installation, test live equipment, replace manufacturer instructions, or qualify anyone for electrical work.
      </div>
      <div className="mt-8 grid gap-4 md:grid-cols-2">
        {labs.map((lab, index) => (
          <Link key={lab.id} href={`/labs/${lab.id}`} className="group rounded-3xl bg-[#101e2e] p-7 text-white transition hover:-translate-y-1">
            <div className="flex items-center justify-between">
              <span className="text-xs tracking-widest text-[var(--on-dark-subtle)]">CONCEPT LAB 0{index + 1} · {lab.minutes} MIN</span>
              <span style={{ background: lab.color }} className="grid size-12 place-items-center rounded-2xl text-xl text-[#101e2e]">{["ϟ", "▥", "⌁", "⌂", "✓"][index]}</span>
            </div>
            <h2 className="mt-8 text-2xl font-semibold">{lab.title}</h2>
            <p className="mt-2 max-w-sm text-sm leading-6 text-[var(--on-dark-muted)]">{lab.subtitle}</p>
            <p className="mt-6 text-sm font-medium" style={{ color: lab.color }}>Enter the concept lab →</p>
          </Link>
        ))}
      </div>
      <LabProgress />
      <p className="text-xs text-[var(--ink-soft)]">Completion records study progress in this browser. Instructor review and supervised practice remain necessary for technical training.</p>
    </div>
  );
}
