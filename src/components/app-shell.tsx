"use client";

import { BarChart3, BookOpen, Bot, ChevronDown, CircleUserRound, ClipboardCheck, LayoutDashboard, Menu, Settings, X } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { BrandMark } from "@/components/brand-mark";
import { QuickSearch } from "@/components/quick-search";
import { cn } from "@/lib/utils";

const navigation = [
  { label: "Overview", href: "/dashboard", icon: LayoutDashboard },
  { label: "Learn", href: "/learn", icon: BookOpen },
  { label: "Interactive labs", href: "/labs", icon: ClipboardCheck },
  { label: "Practice", href: "/practice", icon: ClipboardCheck },
  { label: "Review", href: "/review", icon: BarChart3 },
  { label: "Codebook", href: "/codebook", icon: BookOpen },
  { label: "AI Tutor", href: "/tutor", icon: Bot },
];

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <div className="min-h-screen bg-[#fbfbfa]">
      {mobileOpen && <button aria-label="Close menu" onClick={() => setMobileOpen(false)} className="fixed inset-0 z-40 bg-black/25 backdrop-blur-sm lg:hidden" />}
      <aside className={cn("fixed inset-y-0 left-0 z-50 flex w-[244px] flex-col border-r border-[var(--line)] bg-white px-4 py-5 transition-transform lg:translate-x-0", mobileOpen ? "translate-x-0" : "-translate-x-full")}>
        <div className="flex items-center justify-between px-2">
          <Link href="/dashboard"><BrandMark /></Link>
          <button onClick={() => setMobileOpen(false)} className="grid size-9 place-items-center rounded-full hover:bg-[var(--surface)] lg:hidden"><X className="size-4" /></button>
        </div>

        <div className="mt-8 rounded-2xl border border-[var(--line)] bg-[var(--surface-warm)] p-3">
          <div className="flex items-center gap-2.5">
            <span className="grid size-8 place-items-center rounded-full bg-[var(--ink)] text-xs font-semibold text-white">TJ</span>
            <div className="min-w-0 flex-1"><p className="truncate text-xs font-semibold">Tehron Jones</p><p className="text-[10px] text-[var(--ink-soft)]">Journeyman · California</p></div>
            <ChevronDown className="size-3.5 text-[var(--ink-faint)]" />
          </div>
        </div>

        <nav className="mt-6 space-y-1" aria-label="Main navigation">
          {navigation.map((item) => {
            const active = pathname === item.href || (item.href !== "/dashboard" && pathname.startsWith(`${item.href}/`));
            return (
              <Link key={item.href} href={item.href} onClick={() => setMobileOpen(false)} className={cn("flex h-10 items-center gap-3 rounded-xl px-3 text-[13px] font-medium transition", active ? "bg-[var(--blue-soft)] text-[var(--blue)]" : "text-[var(--ink-soft)] hover:bg-[var(--surface)] hover:text-[var(--ink)]")}>
                <item.icon className="size-[17px]" strokeWidth={1.8} /><span>{item.label}</span>
                {item.label === "AI Tutor" && <span className="ml-auto rounded-full bg-[var(--blue)] px-1.5 py-0.5 text-[8px] font-bold tracking-wide text-white">AI</span>}
              </Link>
            );
          })}
        </nav>

        <div className="mt-auto">
          <div className="mb-4 rounded-2xl bg-[var(--ink)] p-4 text-white">
            <p className="text-[10px] font-semibold uppercase tracking-[.12em] text-white/55">Exam target</p>
            <div className="mt-2 flex items-end justify-between"><p className="text-sm font-semibold">May 24</p><p className="text-[11px] text-white/65">68 days</p></div>
            <div className="mt-3 h-1 overflow-hidden rounded-full bg-white/15"><div className="h-full w-[42%] rounded-full bg-white" /></div>
          </div>
          <Link href="/settings" className="flex h-10 items-center gap-3 rounded-xl px-3 text-[13px] font-medium text-[var(--ink-soft)] hover:bg-[var(--surface)]"><Settings className="size-[17px]" />Settings</Link>
        </div>
      </aside>

      <div className="lg:pl-[244px]">
        <header className="sticky top-0 z-30 flex h-[68px] items-center justify-between border-b border-[var(--line)] bg-white/90 px-4 backdrop-blur-xl md:px-7 lg:px-9">
          <button onClick={() => setMobileOpen(true)} className="grid size-10 place-items-center rounded-full border border-[var(--line)] lg:hidden"><Menu className="size-4" /></button>
          <QuickSearch triggerClassName="ml-auto lg:ml-0 lg:w-[300px]" />
          <div className="flex items-center gap-3">
            <div className="hidden items-center gap-2 rounded-full bg-[var(--surface)] px-3 py-2 text-xs font-semibold md:flex"><span className="text-[var(--blue)]">⚡</span> 1,240 XP</div>
            <Link href="/settings" className="grid size-10 place-items-center rounded-full border border-[var(--line)] bg-white text-[var(--ink-soft)] hover:text-[var(--ink)]"><CircleUserRound className="size-[18px]" /></Link>
          </div>
        </header>
        <main className="min-h-[calc(100vh-68px)]">{children}</main>
      </div>
    </div>
  );
}
