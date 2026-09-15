import * as React from "react";
import { cn } from "@/lib/utils";

function Card({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("rounded-[22px] border border-[var(--line)] bg-white", className)} {...props} />;
}

function CardContent({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("p-5 md:p-6", className)} {...props} />;
}

export { Card, CardContent };
