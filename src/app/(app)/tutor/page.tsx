import { TutorChat } from "@/components/tutor-chat";

export const metadata = { title: "AI Tutor" };
export default async function TutorPage({ searchParams }: { searchParams: Promise<{ prompt?: string }> }) { const {prompt}=await searchParams; return <TutorChat initialPrompt={prompt??""}/>; }
