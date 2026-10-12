import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { OnboardingFlow } from "@/components/onboarding-flow";
import { getViewer } from "@/lib/viewer";

export const metadata: Metadata = { title: "Create your study plan" };

export default async function OnboardingPage() {
  const viewer = await getViewer();
  if (!viewer) redirect("/sign-in?next=/onboarding");
  if (viewer.onboardingComplete && !viewer.isDemo) redirect("/dashboard");
  return <OnboardingFlow />;
}

