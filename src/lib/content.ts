import { BookOpen, Calculator, CircuitBoard, HardHat, PlugZap, ShieldCheck } from "lucide-react";

export type Lesson = {
  slug: string;
  title: string;
  duration: number;
  status: "complete" | "current" | "locked" | "ready";
};

export type Module = {
  slug: string;
  index: string;
  title: string;
  description: string;
  progress: number;
  lessons: Lesson[];
  icon: typeof BookOpen;
};

export const modules: Module[] = [
  {
    slug: "electrical-theory",
    index: "01",
    title: "Electrical theory",
    description: "Build the math and mental models behind voltage, current, resistance, and power.",
    progress: 72,
    icon: CircuitBoard,
    lessons: [
      { slug: "ohms-law", title: "Voltage, current & Ohm’s law", duration: 14, status: "complete" },
      { slug: "watts-law", title: "Power, energy & Watt’s law", duration: 16, status: "current" },
      { slug: "series-parallel", title: "Series and parallel circuits", duration: 18, status: "ready" },
      { slug: "ac-fundamentals", title: "AC fundamentals", duration: 20, status: "ready" },
    ],
  },
  {
    slug: "code-navigation",
    index: "02",
    title: "Navigate the NEC",
    description: "Learn how the Code is organized and find the governing rule under exam pressure.",
    progress: 38,
    icon: BookOpen,
    lessons: [
      { slug: "nec-structure", title: "How the NEC is organized", duration: 12, status: "complete" },
      { slug: "definitions", title: "Article 100 definitions", duration: 15, status: "current" },
      { slug: "tables-index", title: "Using tables and the index", duration: 17, status: "ready" },
      { slug: "exceptions", title: "Reading exceptions and notes", duration: 14, status: "ready" },
    ],
  },
  {
    slug: "wiring-methods",
    index: "03",
    title: "Wiring methods",
    description: "Choose raceways, cables, boxes, and conductor methods with code-first reasoning.",
    progress: 12,
    icon: PlugZap,
    lessons: [
      { slug: "conductors", title: "Conductors and ampacity", duration: 21, status: "current" },
      { slug: "raceways", title: "Raceways and cable systems", duration: 18, status: "ready" },
      { slug: "boxes", title: "Boxes and conduit bodies", duration: 16, status: "ready" },
      { slug: "wet-locations", title: "Wet and damp locations", duration: 13, status: "ready" },
    ],
  },
  {
    slug: "branch-circuits",
    index: "04",
    title: "Branch circuits",
    description: "Work confidently through branch-circuit sizing, loads, and required protections.",
    progress: 0,
    icon: Calculator,
    lessons: [
      { slug: "branch-basics", title: "Branch-circuit fundamentals", duration: 17, status: "ready" },
      { slug: "continuous-loads", title: "Continuous loads", duration: 15, status: "locked" },
      { slug: "required-outlets", title: "Required outlets", duration: 18, status: "locked" },
    ],
  },
  {
    slug: "grounding-bonding",
    index: "05",
    title: "Grounding & bonding",
    description: "Separate commonly confused concepts and trace safe fault-current paths.",
    progress: 0,
    icon: ShieldCheck,
    lessons: [
      { slug: "grounding-purpose", title: "Purpose and terminology", duration: 19, status: "ready" },
      { slug: "electrode-system", title: "Grounding electrode system", duration: 22, status: "locked" },
      { slug: "bonding-paths", title: "Bonding and fault paths", duration: 20, status: "locked" },
    ],
  },
  {
    slug: "jobsite-safety",
    index: "06",
    title: "Jobsite safety",
    description: "Recognize electrical hazards, safe work conditions, and practical risk controls.",
    progress: 0,
    icon: HardHat,
    lessons: [
      { slug: "hazard-recognition", title: "Hazard recognition", duration: 14, status: "ready" },
      { slug: "safe-work", title: "Safe work practices", duration: 16, status: "locked" },
      { slug: "ppe", title: "PPE and approach boundaries", duration: 18, status: "locked" },
    ],
  },
];

export const codeArticles = [
  { article: "100", title: "Definitions", summary: "Essential terms used throughout the Code, from accessible to voltage-to-ground.", tags: ["definitions", "general"] },
  { article: "110", title: "Requirements for electrical installations", summary: "Approval, installation, working space, interrupting ratings, and mechanical execution.", tags: ["working space", "equipment"] },
  { article: "210", title: "Branch circuits", summary: "Ratings, conductor sizing, receptacle requirements, and GFCI/AFCI protection.", tags: ["branch circuits", "gfci"] },
  { article: "240", title: "Overcurrent protection", summary: "Location, ratings, standard sizes, and protection of conductors and equipment.", tags: ["ocpd", "protection"] },
  { article: "250", title: "Grounding and bonding", summary: "System grounding, equipment bonding, electrode systems, and fault-current paths.", tags: ["grounding", "bonding"] },
  { article: "300", title: "General wiring methods", summary: "Physical installation rules that apply across raceway and cable methods.", tags: ["wiring", "conductors"] },
  { article: "310", title: "Conductors for general wiring", summary: "Conductor uses, insulation, ampacity, and temperature limitations.", tags: ["ampacity", "conductors"] },
  { article: "430", title: "Motors and motor circuits", summary: "Motor conductors, overload protection, controllers, and disconnecting means.", tags: ["motors", "controls"] },
];

export type Question = {
  id: number;
  topic: string;
  difficulty: "Foundation" | "Exam level";
  prompt: string;
  options: string[];
  answer: number;
  explanation: string;
  reference: string;
};

export const questions: Question[] = [
  { id: 1, topic: "Electrical theory", difficulty: "Foundation", prompt: "What is the SI unit of electrical resistance?", options: ["Ohm", "Ampere", "Volt", "Watt"], answer: 0, explanation: "The ohm (Ω) measures resistance. Amperes measure current, volts measure potential difference, and watts measure power.", reference: "NEC Article 100" },
  { id: 2, topic: "Electrical theory", difficulty: "Foundation", prompt: "In a purely resistive AC circuit, how are voltage and current related?", options: ["Current lags by 90°", "Current leads by 90°", "They are in phase", "Voltage lags by 45°"], answer: 2, explanation: "In a pure resistive circuit, voltage and current reach their peaks and zero crossings together, so they are in phase.", reference: "AC theory" },
  { id: 3, topic: "Branch circuits", difficulty: "Exam level", prompt: "A continuous load is generally calculated at what percentage for branch-circuit sizing?", options: ["80%", "100%", "125%", "150%"], answer: 2, explanation: "Branch-circuit conductors and overcurrent devices generally size continuous loads at 125%, subject to the applicable equipment rules and exceptions.", reference: "NEC 210.19(A), 210.20(A)" },
  { id: 4, topic: "Code navigation", difficulty: "Exam level", prompt: "When a general NEC rule and a more specific equipment rule both apply, which usually governs?", options: ["The general rule", "The more specific rule", "The rule with the lower article number", "Either rule may be selected"], answer: 1, explanation: "Start with the general rule, then apply the more specific article for the occupancy, equipment, or condition. Specific requirements modify the baseline.", reference: "NEC 90.3" },
  { id: 5, topic: "Grounding & bonding", difficulty: "Exam level", prompt: "What is the primary purpose of equipment bonding?", options: ["Limit normal load current", "Create a low-impedance fault-current path", "Reduce service voltage", "Replace overcurrent protection"], answer: 1, explanation: "Bonding establishes electrical continuity and an effective low-impedance path so fault current can operate the overcurrent device quickly.", reference: "NEC 250.4(A)(5)" },
];

export const lessonContent = {
  slug: "watts-law",
  title: "Power, energy & Watt’s law",
  module: "Electrical theory",
  duration: 16,
  objectives: ["Distinguish power from energy", "Apply Watt’s law in either direction", "Connect circuit ratings to practical limits"],
  sections: [
    { title: "The idea in one minute", body: "Power tells you how quickly electrical energy is being transferred. In a DC or purely resistive circuit, power is voltage multiplied by current: P = V × I. Once you know any two values, you can solve for the third." },
    { title: "Why it matters", body: "Electrical equipment is rated by how much voltage it expects, how much current it draws, and how much power it converts. On the exam, Watt’s law often turns a nameplate rating into the current needed for conductor or circuit decisions." },
    { title: "Work the sequence", body: "Write the values with their units, choose the form of the formula that leaves the unknown by itself, calculate, then ask whether the result is physically reasonable. Keep the electrical calculation separate from any code-required adjustment that follows." },
  ],
};
