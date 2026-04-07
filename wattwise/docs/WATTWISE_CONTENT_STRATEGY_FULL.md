
# WattWise — Content Strategy (Production-Level)

## 0. Purpose

This document defines how all educational content in WattWise is structured, generated, validated, and delivered.

It ensures:
- consistency across lessons, quizzes, and AI responses
- alignment with real electrician exam requirements
- clarity for users at different experience levels
- scalability as content expands

This document is the **single source of truth for content logic**.

---

## 1. Content Philosophy

WattWise content must prioritize:

### 1.1 Clarity Over Complexity
- Explain concepts simply first
- Introduce complexity progressively
- Avoid unnecessary jargon unless required

### 1.2 Understanding Over Memorization
- Every concept must be explainable
- Users should understand *why*, not just *what*

### 1.3 Real Exam Alignment
- Content must reflect actual electrician exam patterns
- Questions should simulate real exam difficulty and structure

### 1.4 Practical Relevance
- Concepts should connect to real-world electrical work when possible

---

## 2. Content Types

### 2.1 Modules
High-level categories of learning.

Examples:
- Electrical Theory
- NEC Code Fundamentals
- Wiring Methods
- Load Calculations
- Safety & Protection

---

### 2.2 Lessons
Structured learning units inside modules.

Each lesson includes:
- title
- learning objective
- explanation content
- NEC references (when applicable)
- key takeaways

---

### 2.3 Quiz Questions

Each question includes:
- question_text
- 4 answer choices
- correct_answer
- explanation
- topic_tag
- difficulty_level

---

### 2.4 NEC Content

NEC content includes:
- code reference (e.g., 210.8)
- simplified explanation
- optional deeper explanation via AI

---

### 2.5 AI-Generated Content

Used for:
- tutor responses
- quiz generation
- explanation expansion
- study recommendations

---

## 3. Lesson Structure Standard

Every lesson must follow this structure:

### 3.1 Introduction
- What the lesson is about
- Why it matters

### 3.2 Core Explanation
- Step-by-step concept breakdown
- Simple language first

### 3.3 NEC Integration
- Relevant code references
- Simplified interpretation

### 3.4 Examples
- Practical scenarios
- Real-world applications

### 3.5 Key Takeaways
- Bullet summary of important points

---

## 4. Difficulty Levels

All content should be tagged:

- Beginner
- Intermediate
- Advanced

### Rules
- Apprentice = mostly Beginner + Intermediate
- Master = Intermediate + Advanced

---

## 5. Quiz Generation Rules

### 5.1 Structure
- Multiple choice (4 options)
- One correct answer

### 5.2 Requirements
- Questions must be realistic
- Avoid trick questions unless exam-accurate
- Distractors must be plausible

### 5.3 Explanations
Each question MUST include:
- why correct answer is correct
- why incorrect answers are wrong

---

## 6. Adaptive Learning Logic

### Inputs
- quiz performance
- lesson completion
- weak topic tracking

### Outputs
- recommended lessons
- targeted quizzes
- tutor suggestions

---

## 7. NEC Content Strategy

### Goals
- simplify complex language
- improve accessibility
- maintain accuracy

### Rules
- never misrepresent code meaning
- label simplified explanations clearly
- allow deeper expansion via AI

---

## 8. AI Content Rules

### Tone
- calm
- clear
- supportive

### Behavior
- step-by-step explanations
- avoid unnecessary verbosity
- adapt to user level

### Safety
- avoid hallucination
- do not invent NEC codes
- clarify uncertainty when needed

---

## 9. Content Quality Standards

Content must be:

- accurate
- consistent
- readable
- aligned with exams
- logically structured

---

## 10. Content Expansion Strategy

Future additions may include:

- more state-specific variations
- advanced simulation exams
- deeper NEC indexing

Focus remains on electrician domain only.

---

## 11. Final Principle

Content is the core of WattWise.

If content is unclear, inaccurate, or inconsistent:
the product fails.

Every piece of content must help the user feel:
- clearer
- more capable
- more prepared
