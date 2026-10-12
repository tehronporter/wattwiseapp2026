import { cn } from "@/lib/utils";

function Progress({ value, className, label = "Progress" }: { value: number; className?: string; label?: string }) {
  return (
    <div className={cn("h-1.5 overflow-hidden rounded-full bg-[var(--line)]", className)} role="progressbar" aria-label={label} aria-valuenow={Math.round(value)} aria-valuemin={0} aria-valuemax={100}>
      <div className="h-full rounded-full bg-[var(--blue)] transition-all duration-500" style={{ width: `${Math.min(100, Math.max(0, value))}%` }} />
    </div>
  );
}

export { Progress };
