"use client";

import { useEffect } from "react";

export default function GlobalError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    console.error(JSON.stringify({ level: "error", message: "unhandled_render_error", error: error.message, digest: error.digest }));
  }, [error]);

  return (
    <html lang="en">
      <body className="grid min-h-screen place-items-center bg-white px-5 text-center">
        <main><p className="text-xs font-bold uppercase tracking-[.14em] text-[var(--error)]">Something went wrong</p><h1 className="mt-3 text-3xl font-bold">WattWise couldn’t load this view.</h1><p className="mt-3 text-sm text-[var(--ink-soft)]">Your saved progress is safe. Try the request again.</p><button onClick={reset} className="mt-6 rounded-full bg-[var(--blue)] px-5 py-3 text-sm font-semibold text-white">Try again</button></main>
      </body>
    </html>
  );
}

