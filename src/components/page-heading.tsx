import { Badge } from "@/components/ui/badge";

export function PageHeading({ eyebrow, title, description, aside }: { eyebrow?: string; title: string; description?: string; aside?: React.ReactNode }) {
  return (
    <div className="flex flex-col justify-between gap-5 md:flex-row md:items-end">
      <div>
        {eyebrow && <p className="mb-3 text-[10px] font-bold uppercase tracking-[.16em] text-[var(--blue)]">{eyebrow}</p>}
        <h1 className="text-3xl font-bold tracking-[-.05em] md:text-[40px]">{title}</h1>
        {description && <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--ink-soft)]">{description}</p>}
      </div>
      {aside ?? <Badge>2026 NEC · California</Badge>}
    </div>
  );
}
