
# WattWise — UI Specification (Production-Level)

## 0. Purpose

This document defines every primary screen, layout, component usage, and interaction pattern for the WattWise iOS app (SwiftUI), aligned to the TEHSO Design System.

It removes ambiguity for engineering. If a behavior is not specified here, it should not be implemented.

---

## 1. Global UI Rules

- Light mode first (white canvas)
- TEHSO Blue (#2E53FF) is the only accent
- Inter typeface only
- 8pt spacing system
- Cards: #F5F5F5, 12px radius
- Icons: line only
- Tap targets ≥ 44pt
- Navigation: Tab-based with per-tab NavigationStack

---

## 2. Navigation Structure

Tabs (left → right):
1. Home
2. Learn
3. Practice
4. Tutor
5. Profile

Tab Bar:
- Minimal background (white)
- Icons default (muted), active icon + label in blue
- No badges except critical alerts (rare)

---

## 3. Screen: Home

### Purpose
Daily engagement hub; drives continuation and habit.

### Layout (top → bottom)
1. Header
   - Greeting (“Pick up where you left off”)
   - Optional date / streak badge (subtle)

2. Continue Learning (PRIMARY CARD)
   - Title (lesson/module name)
   - Subtext (module + progress %)
   - Progress bar (thin, blue)
   - CTA: “Resume”
   - Entire card tappable

3. Today’s Focus (SECONDARY CARD)
   - Recommended action (lesson or quiz)
   - Reason (e.g., “Based on recent mistakes”)
   - CTA: “Start”

4. Daily Goal
   - Minutes progress (e.g., 18 / 30 min)
   - Thin progress bar

5. Quick Actions (horizontal row)
   - Start Quiz
   - Ask Tutor
   - Browse Modules

### States
- New user: show onboarding prompt + “Start first lesson”
- Active: show Continue Learning
- Completed day: subtle “You’re done for today” with optional next action

---

## 4. Screen: Learn (Modules)

### Purpose
Structured curriculum overview.

### Layout
- Vertical list of Module Cards

### Module Card
- Left: index number (01, 02…)
- Title
- Description (1–2 lines)
- Meta: lessons count • est. time
- Progress bar (thin)
- Chevron (→)

### Interaction
- Tap → Module Detail

---

## 5. Screen: Module Detail

### Purpose
List lessons within a module.

### Layout
- Header: module title + overall progress
- List: Lesson Items

### Lesson Item
- Title
- Subtitle (topic)
- Status:
  - Not started
  - In progress (shows %)
  - Completed (check icon)
- Duration

### Interaction
- Tap → Lesson Screen (resume if in-progress)

---

## 6. Screen: Lesson

### Purpose
Primary learning experience.

### Header
- Back
- Title
- Progress (e.g., 2/8)

### Mode Switcher
- Segmented control:
  - Read (default)
  - Slides (optional)
  - Listen (future)

### Content Area (Read Mode)
- Paragraph text (Inter 16–18pt)
- Subheadings
- Bullet lists
- Inline callouts (surface cards)
- NEC references (link-styled in blue)

### Footer Controls
- “Ask Tutor”
- Previous / Next

### Interactions
- Swipe left/right to navigate
- Tap NEC reference → open NEC modal
- Ask Tutor opens contextual chat

### States
- Loading skeleton
- Error: “Couldn’t load lesson. Retry”

---

## 7. Screen: Practice

### Purpose
Entry point for quizzes.

### Layout
- Two primary cards:
  1. Quick Quiz (5–10 questions)
  2. Full Practice Exam (longer, timed)

- Secondary: “Review Weak Areas”

### Interaction
- Tap card → Quiz Start

---

## 8. Screen: Quiz (In-Progress)

### Header
- Back (confirm exit)
- Question index (e.g., 3/10)
- Timer (optional)

### Body
- Question text
- 4 answer options (radio style)

### Answer Cell
- Surface background
- Selected state: subtle blue outline/fill
- Tap to select

### Footer
- Next / Submit (on last question)

### Rules
- Single selection
- Can change before submit

---

## 9. Screen: Quiz Results

### Summary
- Score (%)
- Pass/Fail indicator (subtle)

### Breakdown
- List of questions
- Each shows:
  - User answer
  - Correct answer
  - “Explain” button

### Actions
- Retry quiz
- Study weak topics
- Ask Tutor

---

## 10. Screen: Tutor (AI Chat)

### Purpose
Context-aware assistance.

### Layout
- Message list (chat bubbles)
- Input bar (bottom)

### Message Types
- User (right-aligned)
- Assistant (left-aligned)

### Behavior
- Streaming optional (future)
- Responses:
  - concise
  - structured
  - may include steps/bullets

### Shortcuts
- “Explain last question”
- “Explain NEC concept”

---

## 11. Screen: NEC Lookup

### Access Points
- From Tutor
- From Lesson (links)
- From Search (future)

### Layout
- Search bar (top)
- Results list

### Result Item
- Code reference (e.g., 210.8)
- Title
- Short description

### Detail View
- Full explanation (simplified)
- “Explain further” (AI)

---

## 12. Screen: Profile

### Sections
- User info (email)
- Exam type
- State
- Progress summary
- Access status

### Actions
- Restore access
- Sign out
- Reset progress (confirm modal)

---

## 13. Screen: Paywall

### Layout
- Headline focused on confidence and serious prep
- Supporting subheadline explaining lessons, quizzes, NEC help, and tutor support
- Benefits list
- Two pricing cards:
- Fast Track
- Full Prep
- Calm recommended treatment on Full Prep
- Context note tied to the entry path
- Restore access action

### Rules
- TEHSO white-dominant layout
- TEHSO Blue as the only accent
- Inter only
- Minimal
- No dark patterns
- No subscription-trial framing
- Clear restore option

---

## 14. System States

### Loading
- Skeleton blocks
- No spinners blocking entire screen unless necessary

### Empty
- Calm copy
- Single CTA

### Error
- Short explanation
- Retry action

---

## 15. Motion & Interaction

- Subtle transitions (default SwiftUI)
- No heavy animations
- Respect system gestures

---

## 16. Accessibility

- Dynamic Type support
- High contrast text
- VoiceOver labels for buttons

---

## 17. Final Rules

- Do not introduce new UI patterns without updating this spec
- Do not add colors outside system
- Do not add components not defined here
- Keep screens calm, readable, and focused

This document is the UI source of truth.
