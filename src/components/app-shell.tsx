"use client";

import { BarChart3, BookOpen, Bot, CircleUserRound, ClipboardCheck, LayoutDashboard, Menu, Settings, X } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { BrandMark } from "@/components/brand-mark";
import { QuickSearch } from "@/components/quick-search";
import { cn } from "@/lib/utils";
import type { Viewer } from "@/lib/viewer";

const navigation = [
  { label: "Overview", href: "/dashboard", icon: LayoutDashboard },
  { label: "Learn", href: "/learn", icon: BookOpen },
  { label: "Interactive labs", href: "/labs", icon: ClipboardCheck },
  { label: "Practice", href: "/practice", icon: ClipboardCheck },
  { label: "Review", href: "/review", icon: BarChart3 },
  { label: "Codebook", href: "/codebook", icon: BookOpen },
  { label: "AI Tutor", href: "/tutor", icon: Bot },
];

function examTarget(examDate: string | null) {
  if (!examDate) return { date: "Not scheduled", days: "Set a date" };
  const target = new Date(`${examDate}T12:00:00`);
  const days = Math.max(0, Math.ceil((target.getTime() - Date.now()) / 86_400_000));
  return {
    date: new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric" }).format(target),
    days: `${days} day${days === 1 ? "" : "s"}`,
  };
}

export function AppShell({ children, viewer }: { children: React.ReactNode; viewer: Viewer }) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [isDesktop, setIsDesktop] = useState(false);
  const target = examTarget(viewer.examDate);

  useEffect(() => {
    const mediaQuery = window.matchMedia("(min-width: 1024px)");
    const update = () => setIsDesktop(mediaQuery.matches);
    update();
    mediaQuery.addEventListener("change", update);
    return () => mediaQuery.removeEventListener("change", update);
  }, []);

  useEffect(() => {
    if (!mobileOpen) return;
    const handler = (event: KeyboardEvent) => {
      if (event.key === "Escape") setMobileOpen(false);
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [mobileOpen]);

  return (
    <div className="min-h-screen bg-[#fbfbfa]">
      <a href="#main-content" className="fixed left-3 top-3 z-[100] -translate-y-20 rounded-full bg-[var(--ink)] px-4 py-2 text-xs font-semibold text-white transition focus:translate-y-0">Skip to content</a>
      {mobileOpen && <button aria-label="Close menu" onClick={() => setMobileOpen(false)} className="fixed inset-0 z-40 bg-black/25 backdrop-blur-sm lg:hidden" />}
      <aside id="mobile-navigation" aria-label="Main navigation" aria-hidden={!isDesktop && !mobileOpen} inert={!isDesktop && !mobileOpen} className={cn("fixed inset-y-0 left-0 z-50 flex w-[244px] flex-col border-r border-[var(--line)] bg-white px-4 py-5 transition-transform focus:outline-none lg:translate-x-0", mobileOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0")}>
        <div className="flex items-center justify-between px-2">
          <Link href="/dashboard"><BrandMark /></Link>
          <button aria-label="Close navigation" onClick={() => setMobileOpen(false)} className="grid size-9 place-items-center rounded-full hover:bg-[var(--surface)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--blue)] lg:hidden"><X className="size-4" /></button>
        </div>

        <div className="mt-8 rounded-2xl border border-[var(--line)] bg-[var(--surface-warm)] p-3">
          <div className="flex items-center gap-2.5">
            <span className="grid size-8 place-items-center rounded-full bg-[var(--ink)] text-xs font-semibold text-white">{viewer.initials}</span>
            <div className="min-w-0 flex-1"><p className="truncate text-xs font-semibold">{viewer.fullName}</p><p className="truncate text-[10px] capitalize text-[var(--ink-soft)]">{viewer.track} · {viewer.jurisdiction}</p></div>
          </div>
        </div>

        <nav className="mt-6 space-y-1" aria-label="Main navigation">
          {navigation.map((item) => {
            const active = pathname === item.href || (item.href !== "/dashboard" && pathname.startsWith(`${item.href}/`));
              return (
                <Link key={item.href} href={item.href} aria-current={active ? "page" : undefined} onClick={() => setMobileOpen(false)} className={cn("flex h-10 items-center gap-3 rounded-xl px-3 text-[13px] font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--blue)]", active ? "bg-[var(--blue-soft)] text-[var(--blue)]" : "text-[var(--ink-soft)] hover:bg-[var(--surface)] hover:text-[var(--ink)]")}>
                <item.icon className="size-[17px]" strokeWidth={1.8} /><span>{item.label}</span>
                {item.label === "AI Tutor" && <span className="ml-auto rounded-full bg-[var(--blue)] px-1.5 py-0.5 text-[8px] font-bold tracking-wide text-white">AI</span>}
              </Link>
            );
          })}
        </nav>

        <div className="mt-auto">
          <Link href="/settings#exam-plan" className="mb-4 block rounded-2xl bg-[var(--ink)] p-4 text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--blue)]">
            <p className="text-[10px] font-semibold uppercase tracking-[.12em] text-[var(--on-dark-subtle)]">Exam target</p>
            <div className="mt-2 flex items-end justify-between gap-3"><p className="text-sm font-semibold">{target.date}</p><p className="text-[11px] text-[var(--on-dark-muted)]">{target.days}</p></div>
          </Link>
          <Link href="/settings" className="flex h-10 items-center gap-3 rounded-xl px-3 text-[13px] font-medium text-[var(--ink-soft)] hover:bg-[var(--surface)]"><Settings className="size-[17px]" />Settings</Link>
        </div>
      </aside>

      <div className="lg:pl-[244px]">
        <header className="sticky top-0 z-30 flex h-[68px] items-center justify-between border-b border-[var(--line)] bg-white/90 px-4 backdrop-blur-xl md:px-7 lg:px-9">
          <button aria-label="Open navigation" aria-expanded={mobileOpen} aria-controls="mobile-navigation" onClick={() => setMobileOpen(true)} className="grid size-10 place-items-center rounded-full border border-[var(--line)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--blue)] lg:hidden"><Menu className="size-4" /></button>
          <QuickSearch triggerClassName="ml-auto lg:ml-0 lg:w-[300px]" />
          <div className="flex items-center gap-3">
            <Link href="/settings" aria-label="Open settings and profile" className="grid size-10 place-items-center rounded-full border border-[var(--line)] bg-white text-[var(--ink-soft)] hover:text-[var(--ink)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--blue)]"><CircleUserRound className="size-[18px]" /></Link>
          </div>
        </header>
        <main id="main-content" className="min-h-[calc(100vh-68px)] pb-16 lg:pb-0">{children}</main>
      </div>
      <nav aria-label="Primary mobile navigation" className="fixed inset-x-0 bottom-0 z-40 grid h-16 grid-cols-5 border-t border-[var(--line)] bg-white/95 px-1 pb-[env(safe-area-inset-bottom)] backdrop-blur-xl lg:hidden">
        {navigation.filter((item) => ["Overview", "Learn", "Practice", "Review", "AI Tutor"].includes(item.label)).map((item) => {
          const active = pathname === item.href || (item.href !== "/dashboard" && pathname.startsWith(`${item.href}/`));
          return <Link key={item.href} href={item.href} aria-current={active ? "page" : undefined} className={cn("flex min-w-0 flex-col items-center justify-center gap-1 rounded-lg text-[9px] font-medium", active ? "text-[var(--blue)]" : "text-[var(--ink-soft)]")}><item.icon className="size-[18px]"/><span className="truncate">{item.label === "Overview" ? "Home" : item.label === "AI Tutor" ? "Tutor" : item.label}</span></Link>;
        })}
      </nav>
    </div>
  );
}
