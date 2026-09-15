import * as React from "react";
import { cn } from "@/lib/utils";

function Badge({ className, ...props }: React.ComponentProps<"span">) {
  return <span className={cn("inline-flex h-7 items-center rounded-full bg-[var(--surface)] px-3 text-[11px] font-semibold tracking-[.03em] text-[var(--ink-soft)]", className)} {...props} />;
}

export { Badge };
