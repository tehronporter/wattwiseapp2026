import { Suspense } from "react";
import { TutorChat } from "@/components/tutor-chat";
import { getViewer } from "@/lib/viewer";

export const metadata = { title: "AI Tutor" };
export default async function TutorPage() {
  const viewer = await getViewer();
  return <Suspense fallback={<div className="min-h-[calc(100vh-68px)] bg-white"/>}><TutorChat learnerName={viewer?.fullName ?? "Learner"} track={viewer?.track ?? "journeyman"} jurisdiction={viewer?.jurisdiction ?? "your jurisdiction"}/></Suspense>;
}
