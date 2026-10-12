"use client";

import { ArrowRight, BookOpen, LoaderCircle, Search, Sparkles } from "lucide-react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { codeArticles } from "@/lib/content";
import { env, isSupabaseConfigured } from "@/lib/env";
import { createClient } from "@/lib/supabase/client";

type Result = { id?: string; code: string; title: string; summary: string; edition?: string };

export function CodebookBrowser({ jurisdictionCode }: { jurisdictionCode: string }) {
  const searchParams = useSearchParams();
  const [query, setQuery] = useState(() => searchParams.get("q") ?? "");
  const [remote, setRemote] = useState<Result[] | null>(null);
  const [edition, setEdition] = useState("2026");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");
  const liveSearchEligible = Boolean(query.trim()) && isSupabaseConfigured() && !env.demoMode;
  const curated = useMemo<Result[]>(() => {
    const q = query.toLowerCase().replace("article", "").trim();
    return codeArticles.filter((item) => !q || `${item.article} ${item.title} ${item.summary} ${item.tags.join(" ")}`.toLowerCase().includes(q)).map((item) => ({ code: item.article, title: item.title, summary: item.summary, edition: "2026" }));
  }, [query]);

  useEffect(() => {
    if (!liveSearchEligible) return;
    const controller = new AbortController();
    const timer = window.setTimeout(async () => {
      setPending(true); setError("");
      try {
        const { data, error: invokeError } = await createClient().functions.invoke("nec_search", { body: { query: query.trim(), state_code: jurisdictionCode }, signal: controller.signal });
        if (invokeError || !data?.success) throw new Error(data?.error?.message ?? invokeError?.message ?? "Search failed.");
        setRemote(data.data.results ?? []); setEdition(data.data.edition ?? "2023");
      } catch (cause) {
        if (!controller.signal.aborted) setError(cause instanceof Error ? cause.message : "Code search is unavailable.");
      } finally { if (!controller.signal.aborted) setPending(false); }
    }, 300);
    return () => { window.clearTimeout(timer); controller.abort(); };
  }, [query, jurisdictionCode, liveSearchEligible]);

  const results = (liveSearchEligible ? remote : null) ?? curated;
  return <>
    <div className="mt-8 flex h-14 items-center gap-3 rounded-2xl border border-[var(--line-strong)] bg-white px-4 shadow-[0_8px_28px_rgba(30,35,50,.05)]"><Search className="size-5 text-[var(--ink-faint)]"/><label htmlFor="code-search" className="sr-only">Search NEC study summaries</label><input id="code-search" value={query} onChange={(event) => setQuery(event.target.value)} className="h-full flex-1 bg-transparent text-sm outline-none" placeholder="Search by article, term, or concept…"/>{pending ? <LoaderCircle className="size-4 animate-spin text-[var(--blue)]"/> : <kbd className="hidden rounded-md bg-[var(--surface)] px-2 py-1 text-[10px] text-[var(--ink-faint)] sm:block">{edition} NEC</kbd>}</div>
    {error && <p role="alert" className="mt-3 text-xs text-red-700">Live search is unavailable; showing the curated reference index.</p>}
    <div className="mt-6 grid gap-3 md:grid-cols-2">{results.map((item) => <article key={item.id ?? item.code} className="group rounded-[20px] border border-[var(--line)] bg-white p-5 transition hover:border-[var(--line-strong)] hover:shadow-[0_12px_30px_rgba(30,35,50,.05)]"><div className="flex items-start gap-4"><span className="grid size-11 shrink-0 place-items-center rounded-xl bg-[var(--blue-soft)] text-[var(--blue)]"><BookOpen className="size-4"/></span><div className="min-w-0"><p className="text-[10px] font-bold uppercase tracking-[.14em] text-[var(--blue)]">{item.code.toLowerCase().startsWith("article") ? item.code : `Article ${item.code}`}</p><h2 className="mt-1 text-base font-semibold tracking-[-.02em]">{item.title}</h2><p className="mt-2 text-xs leading-5 text-[var(--ink-soft)]">{item.summary}</p></div></div><div className="mt-5 flex items-center justify-between border-t border-[var(--line)] pt-4"><Link href={`/tutor?prompt=${encodeURIComponent(`Explain NEC ${item.code} ${item.title}`)}`} className="flex items-center gap-2 text-[11px] font-semibold text-[var(--blue)]"><Sparkles className="size-3.5"/>Explain simply</Link><ArrowRight className="size-3.5 text-[var(--ink-faint)] transition group-hover:translate-x-0.5"/></div></article>)}</div>
    {!pending && results.length === 0 && <div className="mt-6 rounded-[20px] border border-dashed border-[var(--line-strong)] p-12 text-center"><p className="font-semibold">No direct match</p><p className="mt-2 text-sm text-[var(--ink-soft)]">Try an article number or a broader concept like “motors.”</p></div>}
  </>;
}
