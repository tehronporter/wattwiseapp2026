import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full text-sm font-semibold transition-all outline-none focus-visible:ring-2 focus-visible:ring-[var(--blue)] focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-45 active:scale-[.98]",
  {
    variants: {
      variant: {
        primary: "bg-[var(--blue)] text-white shadow-[0_8px_24px_rgba(28,67,255,.2)] hover:bg-[var(--blue-hover)]",
        secondary: "border border-[var(--line-strong)] bg-white text-[var(--ink)] hover:border-[var(--ink)] hover:bg-[var(--surface)]",
        ghost: "text-[var(--ink-soft)] hover:bg-[var(--surface)] hover:text-[var(--ink)]",
        soft: "bg-[var(--blue-soft)] text-[var(--blue)] hover:bg-[#dfe5ff]",
        dark: "bg-[var(--ink)] text-white hover:bg-[#292c30]",
      },
      size: {
        default: "h-11 px-5",
        sm: "h-9 px-4 text-xs",
        lg: "h-13 px-7 text-[15px]",
        icon: "size-10 p-0",
      },
    },
    defaultVariants: { variant: "primary", size: "default" },
  },
);

function Button({ className, variant, size, asChild = false, ...props }: React.ComponentProps<"button"> & VariantProps<typeof buttonVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot : "button";
  return <Comp className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}

export { Button, buttonVariants };
