import { Suspense } from "react";
import { QuizExperience } from "@/components/quiz-experience";
import { getViewer } from "@/lib/viewer";

export const metadata = { title: "Adaptive practice", description: "Build mastery with adaptive electrician exam practice and clear answer explanations." };
export default async function PracticePage() {
  const viewer = await getViewer();
  return <Suspense fallback={<div className="min-h-[calc(100vh-68px)] bg-white"/>}><QuizExperience examType={viewer?.track ?? "journeyman"}/></Suspense>;
}
