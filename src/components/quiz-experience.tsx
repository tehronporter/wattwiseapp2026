"use client";

import { ArrowLeft, ArrowRight, BookOpen, Check, RotateCcw, X } from "lucide-react";
import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { questions } from "@/lib/content";
import { cn } from "@/lib/utils";

export function QuizExperience() {
  const [index, setIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<number, number>>({});
  const [checked, setChecked] = useState<Record<number, boolean>>({});
  const [finished, setFinished] = useState(false);
  const question = questions[index];
  const selected = answers[question.id];
  const isChecked = checked[question.id];
  const score = questions.filter((item) => answers[item.id] === item.answer).length;

  function reset() { setIndex(0); setAnswers({}); setChecked({}); setFinished(false); }
  function next() {
    if (!isChecked) { setChecked((value) => ({ ...value, [question.id]: true })); return; }
    if (index === questions.length - 1) { setFinished(true); return; }
    setIndex((value) => value + 1);
  }

  if (finished) return (
    <div className="mx-auto max-w-[820px] px-4 py-10 md:px-8 md:py-16">
      <div className="rounded-[28px] border border-[var(--line)] bg-white p-6 text-center md:p-10">
        <span className="mx-auto grid size-16 place-items-center rounded-full bg-[var(--blue-soft)] text-[var(--blue)]"><Check className="size-7"/></span>
        <p className="mt-6 text-[10px] font-bold uppercase tracking-[.15em] text-[var(--blue)]">Set complete</p><h1 className="mt-2 text-4xl font-bold tracking-[-.055em]">{score} of {questions.length} correct</h1><p className="mx-auto mt-3 max-w-lg text-sm leading-6 text-[var(--ink-soft)]">{score >= 4 ? "Strong work. Your foundation is holding—keep building speed and code navigation." : "Good diagnostic. Review the explanations below, then retry the concepts that need another pass."}</p>
        <div className="mx-auto mt-8 grid max-w-md grid-cols-3 gap-3">{[['Accuracy',`${Math.round(score/questions.length*100)}%`],['XP earned',`+${score*20}`],['Time','6:42']].map(([label,value])=><div key={label} className="rounded-2xl bg-[var(--surface)] p-4"><p className="text-lg font-bold">{value}</p><p className="mt-1 text-[10px] text-[var(--ink-faint)]">{label}</p></div>)}</div>
        <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row"><Button onClick={reset}><RotateCcw className="size-4"/>Try again</Button><Button asChild variant="secondary"><Link href="/review">Review weak areas <ArrowRight className="size-4"/></Link></Button></div>
      </div>
      <div className="mt-6 space-y-3">{questions.map((item,i)=>{const correct=answers[item.id]===item.answer;return <div key={item.id} className="flex items-start gap-3 rounded-2xl border border-[var(--line)] bg-white p-4"><span className={cn("grid size-7 shrink-0 place-items-center rounded-full",correct?"bg-[#e7f5ee] text-[var(--success)]":"bg-[#fff0eb] text-[#bb4b2c]")}>{correct?<Check className="size-3.5"/>:<X className="size-3.5"/>}</span><div><p className="text-sm font-semibold">{i+1}. {item.prompt}</p><p className="mt-1 text-xs text-[var(--ink-soft)]">{correct?'Correct':`Correct answer: ${item.options[item.answer]}`}</p></div></div>})}</div>
    </div>
  );

  return (
    <div className="mx-auto max-w-[920px] px-4 py-8 md:px-8 md:py-12">
      <div className="flex items-center justify-between"><Link href="/dashboard" className="inline-flex items-center gap-2 text-xs font-semibold text-[var(--ink-soft)] hover:text-[var(--ink)]"><ArrowLeft className="size-3.5"/>Exit set</Link><p className="text-xs font-semibold">Question {index+1} <span className="text-[var(--ink-faint)]">of {questions.length}</span></p></div>
      <Progress value={(index/questions.length)*100} className="mt-5"/>
      <div className="mt-10 grid gap-8 md:grid-cols-[1fr_190px]">
        <div><div className="flex gap-2"><span className="rounded-full bg-[var(--blue-soft)] px-3 py-1 text-[10px] font-bold text-[var(--blue)]">{question.topic}</span><span className="rounded-full bg-[var(--surface)] px-3 py-1 text-[10px] font-semibold text-[var(--ink-soft)]">{question.difficulty}</span></div><h1 className="mt-6 text-balance text-2xl font-semibold leading-[1.35] tracking-[-.035em] md:text-[32px]">{question.prompt}</h1>
          <div className="mt-8 space-y-3">{question.options.map((option,optionIndex)=>{const chosen=selected===optionIndex;const correct=isChecked&&optionIndex===question.answer;const wrong=isChecked&&chosen&&optionIndex!==question.answer;return <button disabled={isChecked} onClick={()=>setAnswers(value=>({...value,[question.id]:optionIndex}))} key={option} className={cn("flex w-full items-center gap-4 rounded-2xl border p-4 text-left text-sm transition",!isChecked&&chosen?"border-[var(--blue)] bg-[var(--blue-soft)]":!isChecked?"border-[var(--line)] bg-white hover:border-[var(--line-strong)]":correct?"border-[#acd8c2] bg-[#f0f8f4]":wrong?"border-[#e9b8aa] bg-[#fff4f0]":"border-[var(--line)] bg-white opacity-55")}><span className={cn("grid size-8 shrink-0 place-items-center rounded-full border text-xs font-bold",chosen?"border-[var(--blue)] bg-[var(--blue)] text-white":"border-[var(--line-strong)] text-[var(--ink-soft)]",correct&&"border-[var(--success)] bg-[var(--success)] text-white",wrong&&"border-[#bb4b2c] bg-[#bb4b2c] text-white")}>{correct?<Check className="size-3.5"/>:wrong?<X className="size-3.5"/>:String.fromCharCode(65+optionIndex)}</span><span className="font-medium">{option}</span></button>})}</div>
          {isChecked&&<div className="mt-5 rounded-[18px] bg-[var(--surface)] p-5"><div className="flex items-center gap-2"><BookOpen className="size-4 text-[var(--blue)]"/><p className="text-xs font-bold">Why this answer</p></div><p className="mt-2 text-sm leading-6 text-[var(--ink-soft)]">{question.explanation}</p><p className="mt-3 text-[10px] font-semibold text-[var(--blue)]">{question.reference}</p></div>}
          <div className="mt-7 flex justify-end"><Button disabled={selected===undefined} onClick={next}>{isChecked?(index===questions.length-1?'See results':'Next question'):'Check answer'}<ArrowRight className="size-4"/></Button></div>
        </div>
        <aside className="hidden md:block"><div className="sticky top-24 rounded-[18px] bg-[var(--surface)] p-4"><p className="text-[10px] font-bold uppercase tracking-[.12em] text-[var(--ink-faint)]">Set progress</p><div className="mt-4 grid grid-cols-5 gap-2">{questions.map((item,i)=><span key={item.id} className={cn("grid size-7 place-items-center rounded-lg text-[10px] font-bold",i===index?"bg-[var(--blue)] text-white":checked[item.id]?"bg-white text-[var(--success)]":"bg-white text-[var(--ink-faint)]")}>{checked[item.id]?<Check className="size-3"/>:i+1}</span>)}</div><p className="mt-5 text-xs leading-5 text-[var(--ink-soft)]">Take your time. Accuracy now builds speed later.</p></div></aside>
      </div>
    </div>
  );
}
