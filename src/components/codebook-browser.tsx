"use client";

import { ArrowRight, BookOpen, Search, Sparkles } from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";
import { codeArticles } from "@/lib/content";

export function CodebookBrowser({ initialQuery = "" }: { initialQuery?: string }) {
  const [query, setQuery] = useState(initialQuery);
  const filtered = useMemo(() => {
    const q = query.toLowerCase().replace("article", "").trim();
    if (!q) return codeArticles;
    return codeArticles.filter((item) => `${item.article} ${item.title} ${item.summary} ${item.tags.join(" ")}`.toLowerCase().includes(q));
  }, [query]);
  return <>
    <div className="mt-8 flex h-14 items-center gap-3 rounded-2xl border border-[var(--line-strong)] bg-white px-4 shadow-[0_8px_28px_rgba(30,35,50,.05)]"><Search className="size-5 text-[var(--ink-faint)]"/><input value={query} onChange={(event)=>setQuery(event.target.value)} className="h-full flex-1 bg-transparent text-sm outline-none" placeholder="Search by article, term, or concept…"/><kbd className="hidden rounded-md bg-[var(--surface)] px-2 py-1 text-[10px] text-[var(--ink-faint)] sm:block">2026 NEC</kbd></div>
    <div className="mt-6 grid gap-3 md:grid-cols-2">{filtered.map((item)=><article key={item.article} className="group rounded-[20px] border border-[var(--line)] bg-white p-5 transition hover:border-[var(--line-strong)] hover:shadow-[0_12px_30px_rgba(30,35,50,.05)]"><div className="flex items-start gap-4"><span className="grid size-11 shrink-0 place-items-center rounded-xl bg-[var(--blue-soft)] text-[var(--blue)]"><BookOpen className="size-4"/></span><div className="min-w-0"><p className="text-[10px] font-bold uppercase tracking-[.14em] text-[var(--blue)]">Article {item.article}</p><h2 className="mt-1 text-base font-semibold tracking-[-.02em]">{item.title}</h2><p className="mt-2 text-xs leading-5 text-[var(--ink-soft)]">{item.summary}</p><div className="mt-4 flex flex-wrap gap-1.5">{item.tags.map(tag=><span key={tag} className="rounded-full bg-[var(--surface)] px-2.5 py-1 text-[9px] text-[var(--ink-soft)]">{tag}</span>)}</div></div></div><div className="mt-5 flex items-center justify-between border-t border-[var(--line)] pt-4"><Link href={`/tutor?prompt=${encodeURIComponent(`Explain NEC Article ${item.article} ${item.title}`)}`} className="flex items-center gap-2 text-[11px] font-semibold text-[var(--blue)]"><Sparkles className="size-3.5"/>Explain simply</Link><ArrowRight className="size-3.5 text-[var(--ink-faint)] transition group-hover:translate-x-0.5"/></div></article>)}</div>
    {filtered.length===0&&<div className="mt-6 rounded-[20px] border border-dashed border-[var(--line-strong)] p-12 text-center"><p className="font-semibold">No direct match</p><p className="mt-2 text-sm text-[var(--ink-soft)]">Try an article number or a broader concept like “motors.”</p></div>}
  </>;
}
