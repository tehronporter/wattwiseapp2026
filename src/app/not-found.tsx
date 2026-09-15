import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";

export default function NotFound() { return <main className="grid min-h-screen place-items-center px-5 text-center"><div><p className="text-xs font-bold uppercase tracking-[.15em] text-[var(--blue)]">404</p><h1 className="mt-3 text-4xl font-bold tracking-[-.05em]">That path isn’t on the plan.</h1><p className="mt-3 text-sm text-[var(--ink-soft)]">Head back to your study overview and pick up where you left off.</p><Button asChild className="mt-6"><Link href="/dashboard"><ArrowLeft className="size-4"/>Back to overview</Link></Button></div></main>; }
