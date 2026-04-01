# WattWise — Product Requirements Document (PRD)

## 0. Document Status
Version: 1.0 (Production-Ready)
Owner: Product / TEHSO
Scope: iOS (SwiftUI) + Supabase Backend + AI Layer

---

## 1. Product Summary

WattWise is a focused, AI-powered study companion for electrician licensing exams (Apprentice, Journeyman, and Master), delivering structured learning, adaptive practice, NEC code intelligence, and a context-aware AI tutor within a calm TEHSO-aligned experience.

---

## 2. Goals & Success Metrics

### Primary Goals
- Enable users to pass their electrician licensing exams
- Improve comprehension (not just memorization)
- Increase daily study consistency

### KPIs
- D1 / D7 / D30 retention
- Lesson completion rate
- Quiz completion rate
- Average daily sessions per user
- Conversion to Pro (%)
- Tutor usage per active user

---

## 3. Target Platforms

- iOS (primary)
- iPhone-only initial release
- Future: iPad (optional)

---

## 4. Core App Structure

### Tab Navigation (5 Tabs)
1. Home
2. Learn
3. Practice
4. Tutor
5. Profile

Each tab uses its own NavigationStack.

---

## 5. Feature Breakdown (MVP — FULL)

## 5.1 Authentication

### Features
- Email/password auth
- Apple Sign-In (required for App Store)
- Session persistence

### States
- Logged out
- Logged in
- Session expired

### Edge Cases
- invalid credentials
- network failure
- duplicate accounts

---

## 5.2 Onboarding

### Steps
1. Welcome
2. Select Exam Type:
   - Apprentice
   - Journeyman
   - Master
3. Select State / Jurisdiction
4. Set Study Goal:
   - minutes/day
5. Account creation / login

### Data Captured
- exam_type
- state_code
- study_goal_minutes

---

## 5.3 Home (Dashboard)

### Purpose
Central hub for daily engagement.

### Sections

#### 1. Continue Learning (PRIMARY)
- Last accessed lesson
- Resume button
- Progress indicator

#### 2. Today’s Focus
- Recommended lesson or quiz
- Based on progress + weak areas

#### 3. Daily Goal
- Minutes studied
- Progress bar

#### 4. Streak
- Days active

#### 5. Quick Actions
- Start Quiz
- Open Tutor
- Browse Modules

### States
- New user (empty)
- Active user
- Completed daily goal

---

## 5.4 Learn (Modules)

### Purpose
Structured curriculum.

### Features
- Module list (ordered)
- Progress per module
- Lesson count
- Estimated duration

### Module Structure
- id
- title
- order
- description
- lessons[]

---

## 5.5 Lesson Screen

### Modes
- Read (default)
- Slides (optional)
- Listen (future)

### Components
- Header (title + progress)
- Content body
- Progress indicator
- Mode switcher
- “Ask Tutor” button
- Next / Previous navigation

### Content Types
- text
- bullet explanations
- code references (NEC)

---

## 5.6 Practice (Quiz Engine)

### Quiz Types
- Quick Quiz (short)
- Full Practice Exam (long)

### Question Format
- Multiple choice (4 options)
- One correct answer

### Flow
1. Start quiz
2. Answer questions
3. Submit
4. Results screen

### Features
- timer (optional)
- answer review
- explanation per question
- highlight incorrect answers

### Adaptive Logic
- prioritize weak topics
- reduce repetition of mastered topics

---

## 5.7 AI Tutor

### Purpose
Provide explanations and guidance.

### Features
- chat interface
- context-aware responses
- explain quiz mistakes
- explain NEC code
- follow-up questions

### Behavior Rules
- concise
- step-by-step explanations
- avoid hallucination
- cite NEC concepts when possible

---

## 5.8 NEC Code Lookup

### Features
- search input
- results list
- simplified explanation
- AI expansion (“Explain this”)

### Integration
- accessible from:
  - tutor
  - lessons
  - quiz explanations

---

## 5.9 Progress Tracking

### Metrics
- modules completed
- quiz scores
- weak topics
- study time

### UI
- progress bars
- simple stats (no overload)

---

## 5.10 Profile

### Sections
- user info
- exam type
- state
- subscription status
- reset progress

---

## 5.11 Subscription (Monetization)

### Free Tier
- limited quizzes/day
- limited tutor usage

### Paid Access
- Fast Track access
- Full Prep access
- full content access
- full quiz and tutor access

### Features
- paywall screen
- restore purchases
- preview gating

---

## 6. Non-MVP (Planned Later)

- community discussions
- achievements system
- notifications
- offline-first sync
- advanced analytics

---

## 7. Data Requirements

### Core Entities
- User
- Module
- Lesson
- Question
- QuizAttempt
- TutorSession
- Progress

---

## 8. Edge Cases

- offline usage
- partial quiz submission
- AI timeout
- subscription mismatch
- invalid state selection

---

## 9. Performance Requirements

- screen load < 1s
- tutor response < 3s (initial)
- smooth navigation (60fps)

---

## 10. Security

- no API keys in client
- all AI calls via backend
- RLS enforced in Supabase

---

## 11. UX Principles

- clarity over complexity
- minimal friction
- predictable flows
- calm visual hierarchy (TEHSO)

---

## 12. Definition of Done

Feature is complete when:
- UI matches design system
- backend integration works
- edge cases handled
- no crashes
- passes TestFlight QA

---

## 13. Release Scope (v1)

- Auth
- Onboarding
- Home
- Learn
- Lesson
- Practice
- Tutor
- Profile
- Subscription

No extras.

---

## 14. Final Note

This PRD is the single source of truth for product behavior.

Any feature not defined here should not be built.
