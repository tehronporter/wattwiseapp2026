"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { Component, useState, type ReactNode } from "react";
import { labs, terminals, wireKey, evaluateCircuit, evaluateRoom, parts, faults, meterPoints, safetySteps, saveAttempt, type LabKind, type Wire } from "@/lib/labs";
import styles from "./workbench.module.css";

const Scene = dynamic(() => import("./scene"), { ssr: false, loading: () => <p className="p-8 text-white">Preparing your workbench…</p> });
class SceneBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  render() { return this.state.failed ? <p className="p-8 text-white">3D could not start on this device. Continue with the labeled controls below; all assessments remain available.</p> : this.props.children; }
}

export function LabWorkbench({ kind }: { kind: LabKind }) {
  const lab = labs.find(l => l.id === kind)!;
  const [wires, setWires] = useState<Wire[]>([]);
  const [from, setFrom] = useState(terminals[0]); const [to, setTo] = useState(terminals[3]);
  const [closed, setClosed] = useState(false); const [watts, setWatts] = useState(600);
  const [selected, setSelected] = useState(1); const [exploded, setExploded] = useState(false);
  const [partAnswers, setPartAnswers] = useState<number[]>([]);
  const [fault, setFault] = useState(0); const [measurements, setMeasurements] = useState<number[]>([]);
  const [diagnosed, setDiagnosed] = useState<number[]>([]);
  const [placements, setPlacements] = useState<number[]>([]);
  const [step, setStep] = useState(0); const [mistakes, setMistakes] = useState(0);
  const [hints, setHints] = useState(0); const [feedback, setFeedback] = useState("Explore the brief, then try a decision. Your feedback will appear here.");
  const [coach, setCoach] = useState(false); const [sceneVersion, setSceneVersion] = useState(0);
  const [show3d, setShow3d] = useState(true); const [saved, setSaved] = useState(false);
  const circuit = evaluateCircuit(wires, closed, watts);
  function record(ok: boolean, message: string, score = ok ? Math.max(60, 100 - hints * 5 - mistakes * 10) : 0) {
    setFeedback(message); setSaved(true);
    const persisted = saveAttempt({ id: crypto.randomUUID(), lab: kind, score, completed: ok, feedback: message, hints, at: Date.now() });
    if (!persisted) setFeedback(`${message} Browser storage is unavailable; this attempt could not be saved.`);
  }
  function edit() { setSaved(false); }
  function reset() { setWires([]); setClosed(false); setWatts(600); setSelected(1); setExploded(false); setPartAnswers([]); setFault(0); setMeasurements([]); setDiagnosed([]); setPlacements([]); setStep(0); setMistakes(0); setHints(0); setSaved(false); setFeedback("New attempt. Start with the brief."); setSceneVersion(v => v + 1); }
  function place(i: number) { edit(); setPlacements(p => p.includes(i) ? p.filter(x => x !== i) : [...p, i]); }
  const explanation = kind === "circuit" ? circuit.message : kind === "explorer" ? parts[selected].explanation : kind === "diagnostic" ? faults[fault].hint : kind === "room" ? evaluateRoom(placements).message : safetySteps[Math.min(step, 3)].why;
  const brief = {
    circuit: "Build a 120 V switched resistive load with a separate protective conductor. Connect source L to switch in, switch out to load L, source N to load N, and source PE to load case. Close the switch and keep this training load at or below 15 A.",
    explorer: "Rotate the panel, separate its parts, and answer each component check. This conceptual panel illustrates functions; it is not an installation drawing.",
    diagnostic: "Work through three simulated cases. Take all three voltage readings, then choose the diagnosis supported by the evidence. Measurements are virtual; this is not a procedure for live testing.",
    room: "Design one uninterrupted 20 ft dwelling-room wall. In this exercise, every point must be within 6 ft of a receptacle. Select placement stations, then inspect coverage. Doors, corners, special rooms, and exceptions are outside this brief.",
    safety: "Complete four planning decisions in order. A wrong choice pauses progress and explains the missing control. This is a conceptual sequence, not a complete work procedure.",
  }[kind];
  return <div className={styles.lab}>
    <Link href="/labs" className={styles.back}>← All labs</Link>
    <div className={styles.heading}><div><p className={styles.eyebrow}>Interactive learning / {lab.minutes} min</p><h1>{lab.title}</h1><p>{lab.subtitle}</p></div><button onClick={reset}>Restart exercise</button></div>
    <div className={styles.layout}><div>
      <div className={styles.sceneHeader}><span>WORKBENCH / {kind === "circuit" ? circuit.state.toUpperCase() : "EXPLORE"}</span><button onClick={() => setShow3d(v => !v)}>{show3d ? "Use text mode" : "Show 3D"}</button></div>
      {show3d && <div className={styles.scene}><SceneBoundary key={sceneVersion}><Scene kind={kind} wires={wires} active={circuit.ok} exploded={exploded} selected={selected} onSelect={setSelected} placements={placements} onPlace={place}/></SceneBoundary></div>}
      <div className={styles.sceneFooter}><span>Drag to orbit · scroll to zoom · controls below support keyboard</span><button onClick={() => setSceneVersion(v => v + 1)}>Reset view</button></div>
      <section className={styles.controls} aria-label="Exercise controls">
        {kind === "circuit" && <>
          <h2>Make your connections</h2><div className={styles.row}><label>From<select value={from} onChange={e => setFrom(e.target.value)}>{terminals.map(t => <option key={t}>{t}</option>)}</select></label><label>To<select value={to} onChange={e => setTo(e.target.value)}>{terminals.map(t => <option key={t}>{t}</option>)}</select></label><button onClick={() => { if (from === to) { setFeedback("Choose two different terminals."); return; } const wire = { from, to }; if (wires.some(w => wireKey(w) === wireKey(wire))) { setFeedback("That connection already exists."); return; } edit(); setWires(w => [...w, wire]); }}>Connect</button></div>
          <ul className={styles.connections}>{wires.map((w, i) => <li key={wireKey(w)}><span>{w.from} → {w.to}</span><button aria-label={`Remove ${w.from} to ${w.to}`} onClick={() => { edit(); setWires(ws => ws.filter((_, n) => n !== i)); }}>Remove</button></li>)}</ul>
          <div className={styles.row}><label>Load: {watts} W<input type="range" min="120" max="2400" step="120" value={watts} onChange={e => { edit(); setWatts(Number(e.target.value)); }}/></label><button aria-pressed={closed} onClick={() => { edit(); setClosed(v => !v); }}>Switch: {closed ? "closed" : "open"}</button></div>
          <p className={styles.reading}>{circuit.current.toFixed(1)} A <small>modeled current · 120 V · 15 A exercise rating</small></p><button className={styles.primary} disabled={saved} onClick={() => record(circuit.ok, circuit.message)}>Check and save attempt</button>
        </>}
        {kind === "explorer" && <>
          <div className={styles.row}><h2>Component explorer</h2><button aria-pressed={exploded} onClick={() => setExploded(v => !v)}>{exploded ? "Assemble" : "Explode model"}</button></div>
          <div className={styles.choices}>{parts.map((p, i) => <button key={p.name} aria-pressed={selected === i} onClick={() => setSelected(i)}>{partAnswers.includes(i) ? "✓ " : ""}{p.name}</button>)}</div>
          <h3>{parts[selected].name}</h3><p>{parts[selected].explanation}</p><h3>{parts[selected].question}</h3>
          <div className={styles.choices}>{parts[selected].choices.map((c, i) => <button disabled={partAnswers.includes(selected)} key={c} onClick={() => { if (i === parts[selected].answer) { const next = [...partAnswers, selected]; setPartAnswers(next); setFeedback("Correct. Explore another component."); if (next.length === parts.length) record(true, "All six component checks complete. Review neutral and grounding roles again tomorrow."); } else { setMistakes(m => m + 1); setFeedback(`Try again. ${parts[selected].explanation}`); } }}>{c}</button>)}</div><p>{partAnswers.length}/6 component checks complete</p>
        </>}
        {kind === "diagnostic" && <>
          <h2>Case {fault + 1}: {faults[fault].title}</h2><p>Virtual meter · voltage mode · modeled reference points</p><div className={styles.choices}>{meterPoints.map((p, i) => <button key={p} onClick={() => setMeasurements(m => m.includes(i) ? m : [...m, i])}>{p}: {measurements.includes(i) ? faults[fault].readings[i] : "Measure"}</button>)}</div>
          <h3>What does the evidence support?</h3><div className={styles.choices}>{faults.map(f => <button key={f.answer} disabled={measurements.length < 3 || diagnosed.includes(fault)} onClick={() => { if (f.answer === faults[fault].answer) { const next = [...diagnosed, fault]; setDiagnosed(next); setFeedback(faults[fault].why); if (next.length === faults.length) record(true, "All three cases solved from measurements. " + faults[fault].why); } else { setMistakes(m => m + 1); setFeedback("That diagnosis does not match all readings. " + faults[fault].hint); } }}>{f.answer}</button>)}</div>
          {measurements.length < 3 && <p>Collect all three readings to unlock diagnosis.</p>}{diagnosed.includes(fault) && fault < 2 && <button className={styles.primary} onClick={() => { setFault(f => f + 1); setMeasurements([]); setFeedback("New case: collect fresh evidence."); }}>Next case →</button>}<p>{diagnosed.length}/3 cases solved</p>
        </>}
        {kind === "room" && <>
          <h2>Receptacle placement</h2><p>Select stations in the model or below. Each station is measured from the left end of the wall.</p><div className={styles.choices}>{Array.from({ length: 10 }, (_, i) => <button key={i} aria-pressed={placements.includes(i)} onClick={() => place(i)}>{i * 2 + 1} ft {placements.includes(i) ? "✓" : "+"}</button>)}</div><p>{placements.length} receptacles · {placements.length * 12} illustrative material units</p><button className={styles.primary} disabled={saved} onClick={() => { const result = evaluateRoom(placements); record(result.ok, result.message); }}>Inspect coverage</button>
        </>}
        {kind === "safety" && <>
          <h2>{step < 4 ? `Decision ${step + 1}: ${safetySteps[step].title}` : "Planning sequence complete"}</h2><ol>{safetySteps.map((s, i) => <li key={s.title}>{i < step ? "✓" : "○"} {s.title}</li>)}</ol>
          {step < 4 && <div className={styles.choices}>{safetySteps[step].options.map((o, i) => <button key={o} onClick={() => { if (i === safetySteps[step].correct) { setFeedback(safetySteps[step].why); setStep(s => s + 1); if (step === 3) record(true, "Planning sequence complete. Revisit the explanations for each control before your next scenario."); } else { setMistakes(m => m + 1); setFeedback("Pause and reconsider. " + safetySteps[step].why); } }}>{o}</button>)}</div>}<p>{mistakes} decisions revisited</p>
        </>}
      </section>
    </div><aside className={styles.sidebar}>
      <section><p className={styles.eyebrow}>Your brief</p><p>{brief}</p></section>
      <section aria-live="polite"><p className={styles.eyebrow}>Feedback</p><p>{feedback}</p>{saved && <Link href="/review">View lab history →</Link>}</section>
      <section><div className={styles.row}><h2>Study coach</h2><span className={styles.badge}>GUIDED</span></div><p>Get a hint tied to your current model and decision.</p><button onClick={() => { setHints(h => h + 1); setCoach(true); }}>Explain this state</button>{coach && <p className={styles.coach}>{explanation}</p>}<p className="text-xs">{hints} hints used · guided explanations</p><Link href={`/tutor?lab=${kind}&prompt=${encodeURIComponent(`Help me with ${lab.title}. Current feedback: ${feedback}`)}`}>Continue with tutor →</Link></section>
      <p className={styles.note}>Simplified training model. Saved progress stays in this browser. Models and procedures require instructor review before use in formal training.</p>
    </aside></div>
  </div>;
}
