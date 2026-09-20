export type LabKind = "circuit" | "explorer" | "diagnostic" | "room" | "safety";
export const labs: { id: LabKind; title: string; subtitle: string; minutes: number; color: string }[] = [
  { id: "circuit", title: "Circuit workbench", subtitle: "Connect a circuit. Predict what happens. Test your reasoning.", minutes: 8, color: "#87e5bb" },
  { id: "explorer", title: "Inside the panel", subtitle: "Take apart a panelboard and trace the purpose of every part.", minutes: 6, color: "#a6bcff" },
  { id: "diagnostic", title: "Find the fault", subtitle: "Collect evidence with a virtual meter before choosing a diagnosis.", minutes: 10, color: "#f9ce88" },
  { id: "room", title: "Plan the installation", subtitle: "Place devices and evaluate a room against a design brief.", minutes: 8, color: "#e1b4f7" },
  { id: "safety", title: "Before you begin", subtitle: "Practice the decisions that establish an electrically safe work condition.", minutes: 7, color: "#f3aaa1" },
];

export type Wire = { from: string; to: string };
export const terminals = ["Source L", "Source N", "Source PE", "Switch in", "Switch out", "Load L", "Load N", "Load case"];
export const expectedWires: Wire[] = [
  { from: "Source L", to: "Switch in" }, { from: "Switch out", to: "Load L" },
  { from: "Source N", to: "Load N" }, { from: "Source PE", to: "Load case" },
];
export function wireKey(wire: Wire) { return [wire.from, wire.to].sort().join("|"); }
export function evaluateCircuit(wires: Wire[], closed: boolean, watts: number) {
  const keys = new Set(wires.map(wireKey));
  const unexpected = wires.filter(w => !expectedWires.some(e => wireKey(e) === wireKey(w)));
  const missing = expectedWires.filter(w => !keys.has(wireKey(w)));
  const current = watts / 120;
  // A deliberately constrained trainer: validate the specified topology before simulating it.
  if (unexpected.length) return { ok: false, current: 0, state: "Check connections", message: "A connection differs from this switched-load topology. Inspect it before running the model." };
  if (missing.length) return { ok: false, current: 0, state: "Incomplete", message: `${missing.length} required connection(s) missing, including the protective path to the enclosure.` };
  if (!closed) return { ok: false, current: 0, state: "Switch open", message: "The switch interrupts the load path. Close it to complete this exercise." };
  if (current > 15) return { ok: false, current, state: "Overload", message: `${current.toFixed(1)} A exceeds this exercise’s 15 A rating. This model flags overload; it does not simulate a breaker’s time-current curve.` };
  return { ok: true, current, state: "Operating", message: `${watts} W ÷ 120 V = ${current.toFixed(1)} A. The load has a complete path and the enclosure has a separate protective path.` };
}

export const parts = [
  { name: "Enclosure", color: "#7a8fa3", explanation: "The enclosure contains the equipment and protects its internal parts. Conductive enclosures require an effective bonding connection.", question: "What is the enclosure’s electrical safety role?", choices: ["Carry normal load current", "Provide a bonded protective enclosure", "Replace overcurrent protection"], answer: 1 },
  { name: "Main disconnect", color: "#e9b878", explanation: "The main disconnect interrupts downstream supply. Upstream conductors may remain energized after it opens.", question: "Does opening the main guarantee every part is de-energized?", choices: ["Yes, including upstream terminals", "Only when the lights go out", "No; upstream parts may remain energized"], answer: 2 },
  { name: "Bus assembly", color: "#c99770", explanation: "The bus distributes supply to branch breakers. This conceptual model omits detailed phase geometry.", question: "What does the bus do?", choices: ["Distribute supply to branch breakers", "Act as a grounding electrode", "Measure voltage"], answer: 0 },
  { name: "Branch breakers", color: "#3e5369", explanation: "Branch breakers provide overcurrent protection. Their operation depends on the device rating and trip characteristics.", question: "What is a branch breaker’s primary function?", choices: ["Regulate load voltage", "Provide overcurrent protection", "Replace the neutral"], answer: 1 },
  { name: "Neutral bar", color: "#cfdae5", explanation: "The neutral carries normal return current in applicable circuits. Its bonding arrangement depends on whether this is service equipment or downstream equipment.", question: "Which statement is correct?", choices: ["Neutral and equipment ground always interchange", "Neutral never carries current", "Bonding arrangement depends on equipment location"], answer: 2 },
  { name: "Ground bar", color: "#78bd9a", explanation: "Equipment grounding conductors provide a fault-current path back toward the source. They are not intended to carry normal load current.", question: "What should this path carry in normal operation?", choices: ["No intentional load current", "All neutral current", "Half the circuit load"], answer: 0 },
];

export const faults = [
  { title: "The lamp is dark", readings: ["120 V", "0 V", "0 V"], answer: "Open hot", why: "At this modeled load, neither hot-to-neutral nor hot-to-ground has supply voltage, while the source is present. The hot path is open.", hint: "Compare source voltage with both load measurements." },
  { title: "A missing return path", readings: ["120 V", "Indeterminate", "120 V"], answer: "Open neutral", why: "Hot-to-ground confirms the hot supply in this simplified model. The neutral is floating, so hot-to-neutral is indeterminate; a real reading depends on the circuit and meter.", hint: "The hot is present, but the normal return path is floating." },
  { title: "A healthy circuit?", readings: ["120 V", "120 V", "120 V"], answer: "No fault in these measurements", why: "These measurements are consistent with a healthy modeled supply and return path. They do not certify the entire real installation.", hint: "Do not invent a fault when these measurements agree with the model." },
];
export const meterPoints = ["Source L–N", "Load L–N", "Load L–PE"];
export const safetySteps = [
  { title: "Plan the task", options: ["Identify all sources, stored energy, and the task scope", "Assume the panel label is complete", "Start by removing the cover"], correct: 0, why: "Begin with all possible sources and task hazards; labels alone do not establish the full scope." },
  { title: "Interrupt and isolate", options: ["Rely on a wall switch", "Interrupt the load and isolate every identified source", "Touch the enclosure to check"], correct: 1, why: "Isolation must address every identified supply and stored-energy source through the applicable procedure." },
  { title: "Prevent re-energization", options: ["Tell someone to watch the switch", "Leave a handwritten reminder only", "Apply the applicable lockout/tagout procedure"], correct: 2, why: "The applicable energy-control procedure prevents unexpected re-energization." },
  { title: "Verify absence of voltage", options: ["Use the approved verification procedure, including instrument checks before and after", "Assume darkness proves absence of voltage", "Skip testing once a lock is applied"], correct: 0, why: "A qualified person verifies the relevant points with appropriate equipment and confirms instrument operation before and after the test." },
];

export function evaluateRoom(placements: number[]) {
  // Ten 2-foot stations on one uninterrupted 20-foot practice wall.
  const points = [...new Set(placements)].sort((a, b) => a - b).map(i => i * 2 + 1);
  const gaps = points.slice(1).map((p, i) => p - points[i]);
  const ok = points.length > 0 && points[0] <= 6 && 20 - points[points.length - 1] <= 6 && gaps.every(g => g <= 12);
  return { ok, count: points.length, message: ok ? "Every point along this practice wall is within 6 ft of a receptacle. Explain why the maximum gap between devices is 12 ft." : "Cover both ends within 6 ft and keep gaps between receptacles at 12 ft or less. This exercise covers one uninterrupted wall only." };
}

export type Attempt = { id: string; lab: LabKind; score: number; completed: boolean; feedback: string; at: number; hints: number };
const storageKey = "wattwise.labs.v1";
export function readAttempts(): Attempt[] {
  try {
    const parsed: unknown = JSON.parse(localStorage.getItem(storageKey) || "[]");
    return Array.isArray(parsed) ? parsed.filter((a): a is Attempt => !!a && typeof a === "object" && labs.some(l => l.id === a.lab) && typeof a.id === "string" && Number.isFinite(a.score) && Number.isFinite(a.at) && typeof a.completed === "boolean" && typeof a.feedback === "string") : [];
  } catch { return []; }
}
export function saveAttempt(attempt: Attempt): boolean {
  try { localStorage.setItem(storageKey, JSON.stringify([...readAttempts(), attempt].slice(-200))); window.dispatchEvent(new Event("labs-progress")); return true; } catch { return false; }
}
