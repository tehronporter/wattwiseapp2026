import { Suspense } from "react";
import { PageHeading } from "@/components/page-heading";
import { CodebookBrowser } from "@/components/codebook-browser";
import { getViewer } from "@/lib/viewer";

export const metadata = { title: "Codebook" };
export default async function CodebookPage() {
  const viewer = await getViewer();
  return <div className="mx-auto max-w-[1060px] px-4 py-8 md:px-8 md:py-10 lg:px-10"><PageHeading eyebrow="Adopted-code reference workspace" title="Find the code path" description="Search the NEC structure by article or concept, then connect it to a lesson, explanation, or practice set."/><Suspense fallback={<div className="mt-8 h-14 animate-pulse rounded-2xl bg-[var(--surface)]"/>}><CodebookBrowser jurisdictionCode={viewer?.jurisdictionCode ?? ""}/></Suspense><p className="mt-6 text-[10px] leading-5 text-[var(--ink-faint)]">Educational summaries only. WattWise does not reproduce protected code text. Verify requirements in the official adopted NEC and applicable local amendments.</p></div>;
}
