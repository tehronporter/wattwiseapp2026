"use client";
import Link from "next/link";
import { useSyncExternalStore } from "react";
import { labs, readAttempts } from "@/lib/labs";

function subscribe(callback: () => void) { window.addEventListener("labs-progress", callback); window.addEventListener("storage", callback); return () => { window.removeEventListener("labs-progress", callback); window.removeEventListener("storage", callback); }; }
function snapshot() { return JSON.stringify(readAttempts()); }
export function LabProgress() {
  const data = useSyncExternalStore(subscribe, snapshot, () => "[]");
  const attempts: ReturnType<typeof readAttempts> = JSON.parse(data);
  return <section className="my-6 rounded-2xl border border-[var(--line)] bg-white p-5"><div className="flex items-center justify-between"><h2 className="font-semibold">Lab progress</h2><Link className="text-sm text-[var(--blue)]" href="/labs">Open labs →</Link></div><p className="mt-1 text-xs text-[var(--ink-soft)]">Saved on this browser · {attempts.length} attempts · {new Set(attempts.filter(a => a.completed).map(a => a.lab)).size}/5 labs completed</p><div className="mt-4 grid gap-3 sm:grid-cols-2">{labs.map(l => {
    const history = attempts.filter(a => a.lab === l.id); const recent = history.at(-1);
    return <Link key={l.id} href={`/labs/${l.id}`} className="rounded-xl bg-[var(--surface)] p-3 text-sm"><span className="font-medium">{l.title}</span><p className="mt-1 text-xs text-[var(--ink-soft)]">{recent ? `Latest: ${recent.score}% · ${recent.completed ? "Completed — revisit to retain" : "Needs review"}` : "Ready for your first attempt"}</p></Link>;
  })}</div></section>;
}
