"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";

export default function WorkspaceError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    console.error(JSON.stringify({ level: "error", message: "workspace_render_error", error: error.message, digest: error.digest }));
  }, [error]);
  return <div className="grid min-h-[calc(100vh-68px)] place-items-center px-5 text-center"><div><p className="text-xs font-bold uppercase tracking-[.14em] text-[var(--error)]">Unable to load</p><h1 className="mt-3 text-3xl font-bold">This study view hit a problem.</h1><p className="mt-3 text-sm text-[var(--ink-soft)]">Check your connection and try again.</p><Button onClick={reset} className="mt-6">Retry</Button></div></div>;
}

