"use client";

import { ArrowUp, Bot, BookOpen, Check, Copy, RotateCcw, Sparkles } from "lucide-react";
import { useSearchParams } from "next/navigation";
import { useMemo, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { env, isSupabaseConfigured } from "@/lib/env";
import { labs } from "@/lib/labs";
import { createClient } from "@/lib/supabase/client";

type Message = { role: "assistant" | "user"; text: string; references?: string[]; steps?: string[]; followUps?: string[] };
type TutorResult = { answer: string; steps?: string[]; bullets?: string[]; references?: string[]; follow_ups?: string[]; session_id?: string; usage?: { used: number; limit: number } };
const starters = ["Explain bonding vs. grounding", "Walk me through a load calculation", "Quiz me on Article 210"];

function demoResponse(prompt: string): Message {
  const lower = prompt.toLowerCase();
  if (lower.includes("bond") || lower.includes("ground")) return { role: "assistant", text: "Grounding connects a system to earth to stabilize voltage. Bonding joins conductive parts to make a low-impedance fault-current path. For an exam question, ask whether it is about a voltage reference or returning fault current so the protective device opens.", references: ["NEC 250.4(A)(1)", "NEC 250.4(A)(5)"], followUps: ["Give me a comparison table", "Quiz me on this distinction"] };
  if (lower.includes("load") || lower.includes("watt")) return { role: "assistant", text: "List each load, identify continuous loads, and convert power to current when needed with I = P ÷ V. Apply demand factors next, then size conductors and overcurrent protection as separate decisions.", references: ["Articles 210, 215, and 220"], followUps: ["Give me a worked example", "Quiz me on continuous loads"] };
  return { role: "assistant", text: "First identify the scope, find the general rule, and then check whether a specific article or exception changes it. Tell me the equipment type, voltage, and what the question asks you to size or protect.", references: ["WattWise code-navigation method"], followUps: ["Show me an example", "Turn this into a quiz question"] };
}

export function TutorChat({ learnerName, track, jurisdiction }: { learnerName: string; track: string; jurisdiction: string }) {
  const searchParams = useSearchParams();
  const initialPrompt = searchParams.get("prompt") ?? "";
  const lab = labs.find((item) => item.id === searchParams.get("lab"));
  const greeting = `Hey ${learnerName.split(" ")[0]}—I’m your code-aware study tutor. Ask about a concept or practice question. I’ll keep the explanation focused and show you where to look next.`;
  const initial = useMemo<Message[]>(() => {
    const value: Message[] = [{ role: "assistant", text: greeting }];
    if (initialPrompt) value.push({ role: "user", text: initialPrompt }, lab ? { role: "assistant", text: `You’re reviewing ${lab.title}. Identify the governing concept, compare each observation with your proposed answer, and explain which detail rules out the alternatives.`, references: ["Guided lab review"] } : demoResponse(initialPrompt));
    return value;
  }, [greeting, initialPrompt, lab]);
  const [messages, setMessages] = useState<Message[]>(initial);
  const [input, setInput] = useState("");
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");
  const [usage, setUsage] = useState<{ used: number; limit: number } | null>(null);
  const [copied, setCopied] = useState<number | null>(null);
  const lastPrompt = useRef("");

  async function send(text = input) {
    const clean = text.trim();
    if (!clean || pending) return;
    lastPrompt.current = clean;
    const history = messages.slice(-6).map((item) => ({ role: item.role, content: item.text }));
    setMessages((value) => [...value, { role: "user", text: clean }]);
    setInput(""); setError(""); setPending(true);
    try {
      if (!isSupabaseConfigured() || env.demoMode) {
        await new Promise((resolve) => setTimeout(resolve, 350));
        setMessages((value) => [...value, demoResponse(clean)]);
        return;
      }
      const { data, error: invokeError } = await createClient().functions.invoke("tutor", {
        body: { message: clean, session_id: sessionId, history, context: { type: "general", title: `${track} study session`, examType: track, jurisdiction } },
        headers: { "X-Platform": "web" },
      });
      if (invokeError || !data?.success) throw new Error(data?.error?.message ?? invokeError?.message ?? "Tutor request failed.");
      const result = data.data as TutorResult;
      setSessionId(result.session_id ?? sessionId); setUsage(result.usage ?? null);
      setMessages((value) => [...value, { role: "assistant", text: result.answer, steps: [...(result.steps ?? []), ...(result.bullets ?? [])], references: result.references ?? [], followUps: result.follow_ups ?? [] }]);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "The tutor is unavailable. Try again.");
    } finally { setPending(false); }
  }

  function newChat() {
    if (messages.length > 1 && !window.confirm("Start a new chat? Your saved session will remain in your account.")) return;
    setMessages([{ role: "assistant", text: greeting }]); setSessionId(null); setError(""); setUsage(null);
  }
  async function copyMessage(text: string, index: number) {
    await navigator.clipboard.writeText(text); setCopied(index); window.setTimeout(() => setCopied(null), 1400);
  }

  return <div className="flex min-h-[calc(100vh-68px)] flex-col bg-white">
    <div className="border-b border-[var(--line)] px-4 py-5 md:px-8"><div className="mx-auto flex max-w-[820px] items-center justify-between"><div className="flex items-center gap-3"><span className="grid size-10 place-items-center rounded-xl bg-[var(--blue)] text-white"><Bot className="size-5"/></span><div><h1 className="text-sm font-semibold">WattWise Tutor</h1><p className="mt-0.5 flex items-center gap-1.5 text-[10px] text-[var(--ink-faint)]"><span className="size-1.5 rounded-full bg-[#36a06f]"/>Ready · {track} · {jurisdiction}</p></div></div><Button onClick={newChat} variant="ghost" size="sm"><RotateCcw className="size-3.5"/>New chat</Button></div></div>
    <div className="app-scroll flex-1 overflow-y-auto px-4 py-8 md:px-8" aria-live="polite"><div className="mx-auto max-w-[760px] space-y-6">{messages.map((message, index) => <div key={`${message.role}-${index}`} className={`flex ${message.role === "user" ? "justify-end" : "justify-start"}`}>{message.role === "assistant" && <span className="mr-3 mt-1 grid size-8 shrink-0 place-items-center rounded-lg bg-[var(--blue-soft)] text-[var(--blue)]"><Sparkles className="size-3.5"/></span>}<div className={`max-w-[85%] rounded-[20px] px-4 py-3 text-sm leading-6 md:max-w-[75%] ${message.role === "user" ? "rounded-tr-md bg-[var(--ink)] text-white" : "rounded-tl-md bg-[var(--surface)] text-[var(--ink)]"}`}><p>{message.text}</p>{message.steps && message.steps.length > 0 && <ol className="mt-3 list-decimal space-y-1 pl-5">{message.steps.map((step) => <li key={step}>{step}</li>)}</ol>}{message.references && message.references.length > 0 && <div className="mt-3 flex items-start gap-2 border-t border-black/5 pt-3 text-[10px] font-medium text-[var(--blue)]"><BookOpen className="mt-0.5 size-3 shrink-0"/>{message.references.join(" · ")}</div>}{message.role === "assistant" && index > 0 && <button type="button" onClick={() => copyMessage(message.text, index)} className="mt-2 flex items-center gap-1 text-[10px] text-[var(--ink-faint)] hover:text-[var(--ink)]">{copied === index ? <Check className="size-3"/> : <Copy className="size-3"/>}{copied === index ? "Copied" : "Copy"}</button>}{message.followUps && index === messages.length - 1 && <div className="mt-3 flex flex-wrap gap-2">{message.followUps.map((followUp) => <button type="button" onClick={() => send(followUp)} key={followUp} className="rounded-full border border-[var(--line-strong)] bg-white px-3 py-1 text-[10px] text-[var(--ink-soft)] hover:text-[var(--blue)]">{followUp}</button>)}</div>}</div></div>)}
      {pending && <div className="flex items-center gap-3 text-xs text-[var(--ink-faint)]"><span className="grid size-8 place-items-center rounded-lg bg-[var(--blue-soft)]"><Sparkles className="size-3.5 animate-pulse text-[var(--blue)]"/></span>Working through it…</div>}
      {error && <div role="alert" className="rounded-xl border border-red-200 bg-red-50 p-3 text-xs text-red-700">{error} <button className="font-semibold underline" onClick={() => send(lastPrompt.current)}>Try again</button></div>}
      {messages.length === 1 && <div className="pt-2"><p className="mb-3 text-center text-[10px] font-bold uppercase tracking-[.13em] text-[var(--ink-faint)]">Try asking</p><div className="flex flex-wrap justify-center gap-2">{starters.map((item) => <button type="button" onClick={() => send(item)} key={item} className="rounded-full border border-[var(--line)] bg-white px-4 py-2 text-xs text-[var(--ink-soft)] hover:border-[var(--blue)] hover:text-[var(--blue)]">{item}</button>)}</div></div>}
    </div></div>
    <div className="sticky bottom-0 border-t border-[var(--line)] bg-white/95 px-4 py-4 backdrop-blur-xl md:px-8"><form onSubmit={(event) => { event.preventDefault(); send(); }} className="mx-auto flex max-w-[760px] items-end gap-2 rounded-[20px] border border-[var(--line-strong)] bg-white p-2 shadow-[0_10px_35px_rgba(30,35,50,.08)]"><label htmlFor="tutor-message" className="sr-only">Message the tutor</label><textarea id="tutor-message" rows={1} value={input} onChange={(event) => setInput(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter" && !event.shiftKey) { event.preventDefault(); send(); } }} placeholder="Ask about a concept or practice question…" className="max-h-32 min-h-10 flex-1 resize-none bg-transparent px-3 py-2 text-sm leading-5 outline-none"/><Button type="submit" size="icon" disabled={pending || !input.trim()} aria-label="Send message"><ArrowUp className="size-4"/></Button></form><p className="mx-auto mt-2 max-w-[760px] text-center text-[9px] text-[var(--ink-faint)]">{usage && usage.limit > 0 ? `${usage.used} of ${usage.limit} monthly questions used · ` : ""}Study support, not field guidance. Verify current code and local amendments.</p></div>
  </div>;
}
