import { AppShell } from "@/components/app-shell";
import { redirect } from "next/navigation";
import { getViewer } from "@/lib/viewer";

export default async function WorkspaceLayout({ children }: { children: React.ReactNode }) {
  const viewer = await getViewer();
  if (!viewer) redirect("/sign-in");
  if (!viewer.onboardingComplete && !viewer.isDemo) redirect("/onboarding");
  return <AppShell viewer={viewer}>{children}</AppShell>;
}
