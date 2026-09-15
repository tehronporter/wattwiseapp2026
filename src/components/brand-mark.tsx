import { cn } from "@/lib/utils";

export function BrandMark({ compact = false, inverse = false, className }: { compact?: boolean; inverse?: boolean; className?: string }) {
  return (
    <div className={cn("flex items-center gap-2.5", className)} aria-label="WattWise">
      <span className={cn("grid size-8 place-items-center rounded-[10px]", inverse ? "bg-white text-[var(--blue)]" : "bg-[var(--blue)] text-white") }>
        <svg viewBox="0 0 24 24" className="size-4" fill="none" aria-hidden="true">
          <path d="M4 5.5 8.2 18l3.8-8 3.8 8L20 5.5" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </span>
      {!compact && <span className={cn("text-[17px] font-bold tracking-[-.04em]", inverse && "text-white")}>WattWise</span>}
    </div>
  );
}
