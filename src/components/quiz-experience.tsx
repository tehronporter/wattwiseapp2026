"use client";

import { ArrowLeft, ArrowRight, BookOpen, Check, Flag, LoaderCircle, RotateCcw, TriangleAlert, X } from "lucide-react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { questions as demoQuestions } from "@/lib/content";
import { env, isSupabaseConfigured } from "@/lib/env";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";

type PracticeQuestion = { id: string; topic: string; difficulty: string; prompt: string; options: { key: string; label: string }[] };
type AnswerFeedback = { isCorrect: boolean; correctChoice: string; correctAnswer: string; explanation: string; reference: string | null };
type QuizSummary = { score: number; correctCount: number; totalCount: number; weakTopics: string[] };
type FunctionEnvelope<T> = { success: boolean; data?: T; error?: { message?: string } };

const fallbackQuestions: PracticeQuestion[] = demoQuestions.map((question) => ({
  id: String(question.id), topic: question.topic, difficulty: question.difficulty, prompt: question.prompt,
  options: question.options.map((label, index) => ({ key: String.fromCharCode(65 + index), label })),
}));
const useLivePractice = isSupabaseConfigured() && !env.demoMode;

function topicTitle(slug: string) { return slug.split("-").map((part) => `${part[0]?.toUpperCase() ?? ""}${part.slice(1)}`).join(" "); }

export function QuizExperience({ examType }: { examType: "apprentice" | "journeyman" | "master" }) {
  const searchParams = useSearchParams();
  const topic = searchParams.get("topic")?.trim() ?? "";
  const source = searchParams.get("source")?.trim() || "practice";
  const requestedCount = Math.min(50, Math.max(5, Number(searchParams.get("count")) || 10));
  const [questions, setQuestions] = useState<PracticeQuestion[]>(useLivePractice ? [] : fallbackQuestions);
  const [attemptId, setAttemptId] = useState<string | null>(null);
  const [index, setIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [feedback, setFeedback] = useState<Record<string, AnswerFeedback>>({});
  const [flagged, setFlagged] = useState<Record<string, boolean>>({});
  const [summary, setSummary] = useState<QuizSummary | null>(null);
  const [loading, setLoading] = useState(useLivePractice);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const startedQuestionAt = useRef(0);
  const question = questions[index];
  const selected = question ? answers[question.id] : undefined;
  const currentFeedback = question ? feedback[question.id] : undefined;

  const startSet = useCallback(async () => {
    setError(null); setSummary(null); setIndex(0); setAnswers({}); setFeedback({}); setFlagged({}); startedQuestionAt.current = Date.now();
    if (!useLivePractice) { setQuestions(fallbackQuestions); setAttemptId(null); setLoading(false); return; }
    setLoading(true);
    try {
      const supabase = createClient();
      const { data, error: invokeError } = await supabase.functions.invoke("generate_quiz", { body: { quiz_type: topic ? "weak_area_review" : "quick_quiz", exam_type: examType, topic_tags: topic ? [topic] : [], question_count: requestedCount, source } });
      if (invokeError) throw invokeError;
      const envelope = data as FunctionEnvelope<{ quiz_attempt_id: string; questions: { id: string; question: string; choices: Record<string, string>; topics: string[] }[] }>;
      if (!envelope.success || !envelope.data) throw new Error(envelope.error?.message || "Unable to create a practice set.");
      setAttemptId(envelope.data.quiz_attempt_id);
      setQuestions(envelope.data.questions.map((item) => ({ id: item.id, topic: item.topics[0] ? topicTitle(item.topics[0]) : "Mixed practice", difficulty: "Adaptive", prompt: item.question, options: Object.entries(item.choices).map(([key, label]) => ({ key, label })) })));
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to create a practice set."); }
    finally { setLoading(false); }
  }, [examType, requestedCount, source, topic]);

  // Creating a quiz is the external synchronization this mount effect owns.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void startSet(); }, [startSet]);

  const checkAnswer = useCallback(async () => {
    if (!question || !selected || currentFeedback || submitting) return;
    setSubmitting(true); setError(null);
    try {
      let result: AnswerFeedback;
      if (attemptId && useLivePractice) {
        const supabase = createClient();
        const { data, error: invokeError } = await supabase.functions.invoke("submit_answer", { body: { quiz_attempt_id: attemptId, question_id: question.id, selected, flagged: Boolean(flagged[question.id]), response_ms: Date.now() - startedQuestionAt.current } });
        if (invokeError) throw invokeError;
        const envelope = data as FunctionEnvelope<{ is_correct: boolean; correct_choice: string; correct_answer: string; explanation: string; reference_code: string | null }>;
        if (!envelope.success || !envelope.data) throw new Error(envelope.error?.message || "Unable to submit this answer.");
        result = { isCorrect: envelope.data.is_correct, correctChoice: envelope.data.correct_choice, correctAnswer: envelope.data.correct_answer, explanation: envelope.data.explanation, reference: envelope.data.reference_code };
      } else {
        const demo = demoQuestions.find((item) => String(item.id) === question.id)!;
        const correctChoice = String.fromCharCode(65 + demo.answer);
        result = { isCorrect: selected === correctChoice, correctChoice, correctAnswer: demo.options[demo.answer], explanation: demo.explanation, reference: demo.reference };
      }
      setFeedback((value) => ({ ...value, [question.id]: result }));
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to submit this answer."); }
    finally { setSubmitting(false); }
  }, [attemptId, currentFeedback, flagged, question, selected, submitting]);

  const completeSet = useCallback(async () => {
    if (!questions.length) return;
    setSubmitting(true);
    try {
      if (attemptId && useLivePractice) {
        const supabase = createClient();
        const { data, error: invokeError } = await supabase.functions.invoke("complete_quiz", { body: { quiz_attempt_id: attemptId } });
        if (invokeError) throw invokeError;
        const envelope = data as FunctionEnvelope<{ score: number; correct_count: number; total_count: number; weak_topics: string[] }>;
        if (!envelope.success || !envelope.data) throw new Error(envelope.error?.message || "Unable to complete this set.");
        setSummary({ score: envelope.data.score, correctCount: envelope.data.correct_count, totalCount: envelope.data.total_count, weakTopics: envelope.data.weak_topics });
      } else {
        const correctCount = Object.values(feedback).filter((item) => item.isCorrect).length;
        setSummary({ score: correctCount / questions.length, correctCount, totalCount: questions.length, weakTopics: [] });
      }
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to complete this set."); }
    finally { setSubmitting(false); }
  }, [attemptId, feedback, questions]);

  const advance = useCallback(async () => {
    if (!currentFeedback) { await checkAnswer(); return; }
    if (index === questions.length - 1) { await completeSet(); return; }
    setIndex((value) => value + 1); startedQuestionAt.current = Date.now();
  }, [checkAnswer, completeSet, currentFeedback, index, questions.length]);

  useEffect(() => {
    const handleKey = (event: KeyboardEvent) => {
      if (!question || summary || loading || submitting) return;
      const optionIndex = /^[1-4]$/.test(event.key) ? Number(event.key) - 1 : /^[a-dA-D]$/.test(event.key) ? event.key.toUpperCase().charCodeAt(0) - 65 : -1;
      if (!currentFeedback && optionIndex >= 0 && question.options[optionIndex]) setAnswers((value) => ({ ...value, [question.id]: question.options[optionIndex].key }));
      if (event.key === "Enter" && selected) { event.preventDefault(); void advance(); }
    };
    window.addEventListener("keydown", handleKey); return () => window.removeEventListener("keydown", handleKey);
  }, [advance, currentFeedback, loading, question, selected, submitting, summary]);

  const correctCount = useMemo(() => Object.values(feedback).filter((item) => item.isCorrect).length, [feedback]);

  if (loading) return <StatusView icon={<LoaderCircle className="size-7 animate-spin"/>} title="Preparing your adaptive set…" description="Selecting published questions around your track and current focus." />;
  if (error && !question) return <StatusView icon={<TriangleAlert className="size-7"/>} title="We couldn’t prepare this set." description={error} action={<Button onClick={() => void startSet()}>Try again</Button>} />;
  if (!question) return <StatusView icon={<TriangleAlert className="size-7"/>} title="No questions are available." description="Try a different topic or come back shortly." />;

  if (summary) return (
    <div className="mx-auto max-w-[820px] px-4 py-10 md:px-8 md:py-16">
      <div className="rounded-[28px] border border-[var(--line)] bg-white p-6 text-center md:p-10"><span className="mx-auto grid size-16 place-items-center rounded-full bg-[var(--blue-soft)] text-[var(--blue)]"><Check className="size-7"/></span><p className="mt-6 text-[10px] font-bold uppercase tracking-[.15em] text-[var(--blue)]">Set complete</p><h1 className="mt-2 text-4xl font-bold tracking-[-.055em]">{summary.correctCount} of {summary.totalCount} correct</h1><p className="mx-auto mt-3 max-w-lg text-sm leading-6 text-[var(--ink-soft)]">{summary.score >= 0.8 ? "Strong work. Your next set will continue to balance retention with weaker topics." : "Good diagnostic. Review the explanations below, then return to the weakest topics."}</p>{summary.weakTopics.length > 0 && <p className="mt-4 text-xs text-[var(--ink-soft)]">Review next: {summary.weakTopics.join(", ")}</p>}<div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row"><Button onClick={() => void startSet()}><RotateCcw className="size-4"/>New set</Button><Button asChild variant="secondary"><Link href="/review">Review weak areas <ArrowRight className="size-4"/></Link></Button></div></div>
      <div className="mt-6 space-y-3">{questions.map((item, itemIndex) => { const itemFeedback = feedback[item.id]; return <div key={item.id} className="rounded-2xl border border-[var(--line)] bg-white p-4"><div className="flex items-start gap-3"><span className={cn("grid size-7 shrink-0 place-items-center rounded-full", itemFeedback?.isCorrect ? "bg-[var(--success-soft)] text-[var(--success)]" : "bg-[var(--error-soft)] text-[var(--error)]")} aria-label={itemFeedback?.isCorrect ? "Correct" : "Incorrect"}>{itemFeedback?.isCorrect ? <Check className="size-3.5"/> : <X className="size-3.5"/>}</span><div><p className="text-sm font-semibold">{itemIndex + 1}. {item.prompt}</p>{!itemFeedback?.isCorrect && <p className="mt-1 text-xs text-[var(--ink-soft)]">Correct answer: {itemFeedback?.correctAnswer}</p>}</div></div><div className="mt-3 border-t border-[var(--line)] pt-3"><p className="text-xs leading-5 text-[var(--ink-soft)]">{itemFeedback?.explanation}</p>{itemFeedback?.reference && <p className="mt-2 text-[10px] font-semibold text-[var(--blue)]">{itemFeedback.reference}</p>}</div></div>; })}</div>
    </div>
  );

  return (
    <div className="mx-auto max-w-[920px] px-4 py-8 md:px-8 md:py-12">
      <div className="flex items-center justify-between"><Link href="/dashboard" onClick={(event) => { if (Object.keys(answers).length > 0 && !window.confirm("Exit this set? Your submitted answers are saved, but the set will remain incomplete.")) event.preventDefault(); }} className="inline-flex items-center gap-2 text-xs font-semibold text-[var(--ink-soft)] hover:text-[var(--ink)]"><ArrowLeft className="size-3.5"/>Exit set</Link><p className="text-xs font-semibold">Question {index + 1} <span className="text-[var(--ink-faint)]">of {questions.length}</span></p></div>
      <Progress value={((index + 1) / questions.length) * 100} label={`Set progress: question ${index + 1} of ${questions.length}`} className="mt-5"/>
      <div className="mt-10 grid gap-8 md:grid-cols-[1fr_190px]">
        <div><div className="flex flex-wrap gap-2"><span className="rounded-full bg-[var(--blue-soft)] px-3 py-1 text-[10px] font-bold text-[var(--blue)]">{topic ? topicTitle(topic) : question.topic}</span><span className="rounded-full bg-[var(--surface)] px-3 py-1 text-[10px] font-semibold text-[var(--ink-soft)]">{question.difficulty}</span></div><h1 className="mt-6 text-balance text-2xl font-semibold leading-[1.35] tracking-[-.035em] md:text-[32px]">{question.prompt}</h1>
          <div className="mt-8 space-y-3">{question.options.map((option, optionIndex) => { const chosen = selected === option.key; const correct = currentFeedback && option.key === currentFeedback.correctChoice; const wrong = currentFeedback && chosen && !currentFeedback.isCorrect; return <button aria-label={`Option ${String.fromCharCode(65 + optionIndex)}: ${option.label}`} aria-pressed={chosen} disabled={Boolean(currentFeedback)} onClick={() => setAnswers((value) => ({ ...value, [question.id]: option.key }))} key={option.key} className={cn("flex w-full items-center gap-4 rounded-2xl border p-4 text-left text-sm transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]", !currentFeedback && chosen ? "border-[var(--blue)] bg-[var(--blue-soft)]" : !currentFeedback ? "border-[var(--line)] bg-white hover:border-[var(--line-strong)]" : correct ? "border-[var(--success)] bg-[var(--success-soft)]" : wrong ? "border-[var(--error)] bg-[var(--error-soft)]" : "border-[var(--line)] bg-white opacity-55")}><span className={cn("grid size-8 shrink-0 place-items-center rounded-full border text-xs font-bold", chosen ? "border-[var(--blue)] bg-[var(--blue)] text-white" : "border-[var(--line-strong)] text-[var(--ink-soft)]", correct && "border-[var(--success)] bg-[var(--success)] text-white", wrong && "border-[var(--error)] bg-[var(--error)] text-white")}>{correct ? <Check className="size-3.5"/> : wrong ? <X className="size-3.5"/> : String.fromCharCode(65 + optionIndex)}</span><span className="font-medium">{option.label}</span></button>; })}</div>
          {currentFeedback && <div aria-live="polite" className="mt-5 rounded-[18px] bg-[var(--surface)] p-5"><div className="flex items-center gap-2"><BookOpen className="size-4 text-[var(--blue)]"/><p className="text-xs font-bold">{currentFeedback.isCorrect ? "Correct" : `Correct answer: ${currentFeedback.correctAnswer}`}</p></div><p className="mt-2 text-sm leading-6 text-[var(--ink-soft)]">{currentFeedback.explanation}</p>{currentFeedback.reference && <p className="mt-3 text-[10px] font-semibold text-[var(--blue)]">{currentFeedback.reference}</p>}</div>}
          {error && <p role="alert" className="mt-4 rounded-xl bg-[var(--error-soft)] px-3 py-2 text-xs text-[var(--error)]">{error}</p>}
          <div className="mt-7 flex items-center justify-between"><Button type="button" variant="ghost" aria-pressed={Boolean(flagged[question.id])} onClick={() => setFlagged((value) => ({ ...value, [question.id]: !value[question.id] }))}><Flag className="size-4"/>{flagged[question.id] ? "Flagged" : "Flag for review"}</Button><Button disabled={!selected || submitting} onClick={() => void advance()}>{submitting ? "Saving…" : currentFeedback ? index === questions.length - 1 ? "See results" : "Next question" : "Check answer"}<ArrowRight className="size-4"/></Button></div>
        </div>
        <aside className="hidden md:block"><div className="sticky top-24 rounded-[18px] bg-[var(--surface)] p-4"><p className="text-[10px] font-bold uppercase tracking-[.12em] text-[var(--ink-faint)]">Set progress</p><div className="mt-4 grid grid-cols-5 gap-2">{questions.map((item, itemIndex) => <span key={item.id} className={cn("grid size-7 place-items-center rounded-lg text-[10px] font-bold", itemIndex === index ? "bg-[var(--blue)] text-white" : feedback[item.id]?.isCorrect ? "bg-[var(--success-soft)] text-[var(--success)]" : feedback[item.id] ? "bg-[var(--error-soft)] text-[var(--error)]" : "bg-white text-[var(--ink-faint)]")}>{feedback[item.id] ? feedback[item.id].isCorrect ? <Check className="size-3"/> : <X className="size-3"/> : itemIndex + 1}</span>)}</div><p className="mt-5 text-xs leading-5 text-[var(--ink-soft)]">{correctCount > 1 ? `${correctCount} correct so far. Keep your process consistent.` : "Use A–D or 1–4 to choose, then Enter to submit."}</p></div></aside>
      </div>
    </div>
  );
}

function StatusView({ icon, title, description, action }: { icon: React.ReactNode; title: string; description: string; action?: React.ReactNode }) {
  return <div className="grid min-h-[calc(100vh-68px)] place-items-center px-5 text-center"><div><span className="mx-auto grid size-14 place-items-center rounded-full bg-[var(--blue-soft)] text-[var(--blue)]">{icon}</span><h1 className="mt-5 text-2xl font-bold">{title}</h1><p className="mx-auto mt-2 max-w-md text-sm leading-6 text-[var(--ink-soft)]">{description}</p>{action && <div className="mt-5">{action}</div>}</div></div>;
}
