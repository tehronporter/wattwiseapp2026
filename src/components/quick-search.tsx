"use client";

import * as Dialog from "@radix-ui/react-dialog";
import { ArrowRight, BookOpen, Search, Sparkles } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { codeArticles, modules } from "@/lib/content";

export function QuickSearch({ triggerClassName = "" }: { triggerClassName?: string }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setOpen((value) => !value);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, []);

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return codeArticles.slice(0, 3).map((item) => ({ label: `Article ${item.article}`, detail: item.title, href: `/codebook?q=${item.article}`, type: "Code" }));
    const articles = codeArticles.filter((item) => `${item.article} ${item.title} ${item.summary} ${item.tags.join(" ")}`.toLowerCase().includes(q)).map((item) => ({ label: `Article ${item.article}`, detail: item.title, href: `/codebook?q=${item.article}`, type: "Code" }));
    const learning = modules.filter((item) => `${item.title} ${item.description}`.toLowerCase().includes(q)).map((item) => ({ label: item.title, detail: `${item.lessons.length} lessons`, href: `/learn/${item.slug}`, type: "Learn" }));
    return [...articles, ...learning].slice(0, 6);
  }, [query]);

  return (
    <Dialog.Root open={open} onOpenChange={setOpen}>
      <Dialog.Trigger asChild>
        <button className={`flex h-10 items-center gap-2 rounded-full border border-[var(--line)] bg-white px-3 text-sm text-[var(--ink-soft)] transition hover:border-[var(--line-strong)] hover:text-[var(--ink)] ${triggerClassName}`}>
          <Search className="size-4" /><span className="hidden lg:inline">Search lessons or the NEC</span><kbd className="ml-2 hidden rounded-md bg-[var(--surface)] px-2 py-0.5 text-[10px] font-semibold lg:inline">⌘ K</kbd>
        </button>
      </Dialog.Trigger>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-50 bg-[#111318]/35 backdrop-blur-sm" />
        <Dialog.Content className="fixed left-1/2 top-[14vh] z-50 w-[calc(100%-32px)] max-w-xl -translate-x-1/2 overflow-hidden rounded-[24px] border border-white/60 bg-white shadow-[0_30px_90px_rgba(18,24,40,.24)] outline-none">
          <Dialog.Title className="sr-only">Search WattWise</Dialog.Title>
          <div className="flex items-center gap-3 border-b border-[var(--line)] px-5">
            <Search className="size-5 text-[var(--ink-faint)]" />
            <input autoFocus value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search “grounding”, “Article 250”…" className="h-16 flex-1 bg-transparent text-[15px] outline-none placeholder:text-[var(--ink-faint)]" />
            <Dialog.Close className="rounded-md bg-[var(--surface)] px-2 py-1 text-[10px] font-semibold text-[var(--ink-soft)]">ESC</Dialog.Close>
          </div>
          <div className="p-2">
            <p className="px-3 pb-2 pt-2 text-[10px] font-bold uppercase tracking-[.14em] text-[var(--ink-faint)]">{query ? "Results" : "Quick access"}</p>
            {results.map((item) => (
              <Dialog.Close asChild key={`${item.type}-${item.label}`}>
                <Link href={item.href} className="group flex items-center gap-3 rounded-2xl px-3 py-3 hover:bg-[var(--surface)]">
                  <span className="grid size-9 place-items-center rounded-xl bg-[var(--blue-soft)] text-[var(--blue)]">{item.type === "Code" ? <BookOpen className="size-4" /> : <Sparkles className="size-4" />}</span>
                  <span className="min-w-0 flex-1"><span className="block text-sm font-semibold">{item.label}</span><span className="block truncate text-xs text-[var(--ink-soft)]">{item.detail}</span></span>
                  <ArrowRight className="size-4 text-[var(--ink-faint)] transition group-hover:translate-x-0.5 group-hover:text-[var(--blue)]" />
                </Link>
              </Dialog.Close>
            ))}
            {results.length === 0 && <div className="px-3 py-9 text-center text-sm text-[var(--ink-soft)]">No exact match. Try a topic or article number.</div>}
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
