import { notFound } from "next/navigation";
import { labs } from "@/lib/labs";
import { LabWorkbench } from "@/components/labs/workbench";
export function generateStaticParams() { return labs.map(l => ({ lab: l.id })); }
export default async function LabPage({ params }: { params: Promise<{ lab: string }> }) {
  const { lab } = await params;
  const item = labs.find(l => l.id === lab);
  if (!item) notFound();
  return <LabWorkbench kind={item.id}/>;
}
