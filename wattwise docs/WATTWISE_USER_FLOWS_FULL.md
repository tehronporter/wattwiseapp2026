
# WattWise — User Flows (Production-Level)

## 0. Purpose

This document defines the primary user journeys, decision points, transitions, and edge-case behaviors for WattWise. It exists to ensure the product feels seamless, predictable, and focused from first launch through long-term retention.

These flows are the behavioral source of truth for product, design, and engineering. If a user journey is not defined here, it should not be improvised during implementation.

---

## 1. Flow Design Principles

All WattWise user flows must follow these principles:

### 1.1 Clarity First
Users should always know:
- where they are
- what they are doing
- what happens next

### 1.2 Minimal Friction
No unnecessary steps, repeated confirmations, or dead-end screens.

### 1.3 Continuity
The app should remember where the user left off and make resuming effortless.

### 1.4 Guided, Not Pushy
The app should recommend the next best action without feeling manipulative or noisy.

### 1.5 State-Aware
Flows must adapt to:
- new users
- returning users
- subscribed vs free users
- users with weak-topic history
- users with incomplete lessons or quizzes

---

## 2. Primary User Types

### 2.1 First-Time User
A user opening WattWise for the first time with no account, no study preferences, and no saved progress.

### 2.2 Returning Active User
A user with an account, selected exam type/state, and existing study history.

### 2.3 Returning Inactive User
A user who previously onboarded but has been absent long enough that the app should re-establish direction.

### 2.4 Free User
A user on the free plan with limited tutor/quizzes/content access.

### 2.5 Pro User
A paying subscriber with full access.

---

## 3. First Launch Flow

## 3.1 First App Open

### Entry Condition
- App installed
- No authenticated session
- No onboarding completion

### Flow
1. Splash / launch screen
2. Welcome screen
3. Intro value proposition
4. Tap primary CTA: “Get Started”
5. Begin onboarding flow

### Requirements
- No forced account creation before basic context is introduced
- Tone should be calm and confident
- No overwhelming feature dump

### Goal
Move the user into onboarding with confidence and low friction.

---

## 4. Onboarding Flow

## 4.1 Welcome → Exam Type → State → Goal → Account

### Flow Sequence

#### Step 1 — Welcome
Purpose:
- Introduce WattWise simply
- Set tone
- Establish that this is a focused electrician study app

Primary CTA:
- Continue

Secondary CTA:
- Sign In

#### Step 2 — Choose Exam Type
Options:
- Apprentice
- Master

Rules:
- One selection required
- Selection becomes part of profile and content logic
- Can be changed later in settings, but not casually during onboarding without confirmation

#### Step 3 — Choose State / Jurisdiction
Purpose:
- Specialize learning path and exam context

Rules:
- One state required
- Searchable list or grouped picker
- Selection affects curriculum, question pools, and future readiness logic

#### Step 4 — Set Study Goal
Examples:
- 15 min/day
- 30 min/day
- 45 min/day
- 60 min/day

Rules:
- One option required
- Goal powers daily progress UI

#### Step 5 — Create Account / Sign In
Options:
- Continue with Apple
- Email sign up
- Sign in

Rules:
- If the user already has an account, allow switching cleanly
- Preserve onboarding selections until account creation completes

#### Step 6 — Onboarding Completion
Outcome:
- Profile created
- Preferences saved
- User enters Home screen

### End State
User lands on Home with:
- Continue Learning replaced by “Start your first lesson”
- Today’s Focus initialized
- Daily goal visible

---

## 5. Authentication Flows

## 5.1 Email Sign Up Flow

### Flow
1. User enters email
2. User enters password
3. User confirms password if required
4. Submit
5. Show success or verification state
6. Enter app

### Edge Cases
- Invalid email
- Weak password
- Email already in use
- Network failure

### Requirements
- Error messages must be short and actionable
- Preserve typed input unless security requires clearing it

---

## 5.2 Apple Sign-In Flow

### Flow
1. Tap “Continue with Apple”
2. System sheet opens
3. User authenticates
4. Account created or mapped
5. User enters app

### Requirements
- Works cleanly for both first-time and returning users
- Handle private relay email correctly
- Do not create duplicate profiles

---

## 5.3 Sign In Flow

### Flow
1. Tap Sign In
2. Enter credentials or use Apple
3. Submit
4. Route user to Home

### Edge Cases
- Wrong password
- Unknown account
- Expired session
- Account exists with different sign-in method

---

## 5.4 Session Restore Flow

### Entry Condition
- App reopens with valid session token

### Flow
1. Launch app
2. Validate session
3. Load user profile and progress
4. Route directly to Home

### Requirement
Session restore should feel instant and invisible.

---

## 6. Core Daily Loop

This is the most important loop in the product.

### Ideal Repeat Behavior
User opens WattWise daily, resumes their learning, practices weak areas, and leaves feeling clear about progress.

### Daily Loop Flow
1. Open app
2. Land on Home
3. See Continue Learning or Today’s Focus
4. Resume lesson or begin recommended quiz
5. Complete learning action
6. See progress update
7. Optionally ask Tutor
8. Exit app with clear next step saved

---

## 7. Home Flow

## 7.1 New User Home Flow

### Entry Condition
- Onboarding complete
- No lessons started

### Screen Behavior
- Continue Learning area becomes “Start your first lesson”
- Today’s Focus recommends Module 1 / Lesson 1
- Quick actions visible but secondary

### Primary Action
- Start first lesson

### Goal
Immediate movement into structured learning.

---

## 7.2 Returning Active User Home Flow

### Entry Condition
- At least one lesson or quiz exists

### Screen Behavior
- Continue Learning card shows last in-progress lesson
- Today’s Focus recommends the best next action
- Daily goal reflects current progress
- Quick actions remain available

### Priority Rules
1. In-progress lesson has highest priority
2. If no in-progress lesson, recommend weak-topic quiz
3. If strong recent quiz history but no lesson, recommend next module lesson

---

## 7.3 Returning Inactive User Home Flow

### Entry Condition
- User has history but has not opened app recently

### Screen Behavior
- Continue Learning still available
- Today’s Focus may use re-entry messaging like:
  - “Pick up where you left off”
  - “Start with a quick refresher”
- Avoid guilt language

### Goal
Reduce re-entry friction and restart momentum.

---

## 8. Learning Flows

## 8.1 Learn Tab → Module Detail → Lesson

### Flow
1. User taps Learn tab
2. User sees ordered module list
3. User selects a module
4. User sees module detail with lessons
5. User taps lesson
6. User enters lesson screen

### Requirements
- User must always know progress at both module and lesson level
- Completed content should remain visible, not hidden

---

## 8.2 Lesson Progression Flow

### Inside Lesson
1. User opens lesson
2. Reads content in default Read mode
3. Moves between sections/pages
4. Optionally taps NEC reference
5. Optionally opens Tutor
6. Taps Next
7. Lesson progress saves automatically

### Completion Rules
A lesson is marked completed when:
- user reaches final section and completes final step
or
- user explicitly completes the lesson if completion action is required

### Resume Rules
If the user exits mid-lesson:
- progress should persist
- Continue Learning must bring them back to exact lesson state if feasible

---

## 8.3 Lesson → Tutor Contextual Flow

### Trigger
- User taps “Ask Tutor” while inside lesson

### Behavior
- Tutor opens with lesson context attached
- Suggested prompt may appear:
  - “Explain this lesson more simply”
  - “What does this NEC rule mean?”
  - “Give me a practical example”

### Requirement
The user should not need to manually restate context.

---

## 8.4 Lesson → NEC Flow

### Trigger
- User taps NEC reference inside lesson

### Behavior
1. NEC reference opens modal or detail screen
2. User sees simplified summary
3. User can tap “Explain Further”
4. AI expands on the code section

### Goal
Make NEC feel accessible instead of intimidating.

---

## 9. Practice Flows

## 9.1 Practice Entry Flow

### Flow
1. User taps Practice tab
2. User sees options:
   - Quick Quiz
   - Full Practice Exam
   - Review Weak Areas
3. User selects an option
4. Quiz setup begins

### Rules
- Defaults should be sensible
- Free-tier limits may be enforced here if applicable
- Locked options must explain why clearly

---

## 9.2 Quick Quiz Flow

### Flow
1. Tap Quick Quiz
2. Generate short quiz
3. Enter quiz screen
4. Answer each question
5. Submit final answer set
6. View results
7. Choose next step:
   - Retry
   - Review weak areas
   - Ask Tutor

### Goal
Fast study loop with low friction.

---

## 9.3 Full Practice Exam Flow

### Flow
1. Tap Full Practice Exam
2. Select or confirm exam settings if needed
3. Begin longer timed quiz
4. Answer all questions
5. Submit
6. Review results

### Rules
- Exiting mid-exam should require confirmation
- If save/resume exists, it must be explicit and reliable
- Timer logic must be consistent

---

## 9.4 Review Weak Areas Flow

### Trigger
- User taps “Review Weak Areas” from Practice or Results

### Behavior
1. App identifies weakest concepts/topics
2. Generates quiz or lesson recommendations
3. User starts targeted review

### Goal
Transform mistakes into next actions.

---

## 10. Quiz In-Progress Flow

## 10.1 Question Answering Flow

### Flow
1. Show question
2. User selects one answer
3. User taps Next
4. App saves answer state
5. Load next question

### Rules
- One answer per question
- User may change answer before submission
- Progress should persist through temporary interruptions if feasible

---

## 10.2 Exit Quiz Flow

### Trigger
- User taps back / close during quiz

### Behavior
Show confirmation:
- Continue Quiz
- Exit Quiz

If autosave exists:
- copy must state that progress is saved
If autosave does not exist:
- copy must clearly warn that progress will be lost

---

## 10.3 Quiz Submission Flow

### Flow
1. Final question completed
2. User taps Submit
3. Optional submit confirmation if appropriate
4. App grades quiz
5. Results screen loads

### Requirement
Grading should feel immediate and clear.

---

## 11. Results & Review Flows

## 11.1 Quiz Results Flow

### Screen Must Show
- score
- completion status
- question review list
- explanations
- next-step actions

### Post-Results Actions
- Retry quiz
- Review weak topics
- Ask Tutor about missed questions
- Return Home

---

## 11.2 Results → Tutor Flow

### Trigger
- User taps “Explain” or “Ask Tutor” on a missed question

### Behavior
- Tutor opens with missed-question context
- Suggested system framing:
  - why answer was wrong
  - why correct answer is right
  - related NEC/code logic if applicable

### Requirement
This flow must feel direct and intelligent.

---

## 12. Tutor Flows

## 12.1 General Tutor Entry Flow

### Entry Points
- Tutor tab
- Lesson contextual button
- Quiz results explanation button
- NEC detail “Explain Further”

### Behavior
Tutor should know source context when entered contextually.

If opened from Tutor tab directly:
- show empty chat state
- provide useful starter prompts

---

## 12.2 Tutor Chat Flow

### Flow
1. User enters prompt
2. App sends request
3. AI responds
4. User asks follow-up
5. Conversation continues

### Response Requirements
- concise by default
- step-by-step when helpful
- plain language first
- should avoid overlong lecture-style replies

---

## 12.3 Tutor Failure Flow

### Edge Cases
- network timeout
- provider error
- malformed response
- quota limit reached

### Behavior
Show short message with next step:
- Retry
- Try again later
- Upgrade if free limit reached

Do not destroy existing conversation state.

---

## 13. NEC Lookup Flows

## 13.1 Search Flow

### Flow
1. User opens NEC lookup
2. Enters search term or reference
3. Results list loads
4. User taps result
5. Detail explanation opens

### Search Inputs May Include
- reference number
- keyword
- phrase
- concept

### Requirement
Search should tolerate imperfect user wording.

---

## 13.2 NEC Detail → AI Expansion Flow

### Flow
1. User opens NEC result
2. Reads simplified summary
3. Taps “Explain Further”
4. AI provides deeper explanation
5. User may ask follow-up questions

### Goal
Blend structured reference + adaptive explanation.

---

## 14. Profile Flows

## 14.1 View Profile Flow

### Contents
- account info
- exam type
- state
- subscription
- study summary

### Purpose
Simple settings and account clarity, not a cluttered dashboard.

---

## 14.2 Update Exam Type / State Flow

### Behavior
User may update exam type or state from Profile/Settings.

### Rules
Because this affects curriculum and recommendations:
- show confirmation before applying major changes
- explain that recommendations and progress context may shift
- preserve old progress unless reset is explicitly requested

---

## 14.3 Reset Progress Flow

### Behavior
- user taps Reset Progress
- confirmation modal appears
- user confirms or cancels

### Rules
This must be hard to do accidentally.

---

## 14.4 Sign Out Flow

### Behavior
- user taps Sign Out
- optional confirmation if needed
- session cleared
- app returns to auth flow

---

## 15. Subscription Flows

## 15.1 Free User Limit Reached Flow

### Triggers
- quiz limit reached
- tutor quota reached
- locked lesson/content accessed

### Behavior
1. User attempts premium action
2. Paywall appears
3. Clear value explanation shown
4. User can:
   - subscribe
   - restore
   - dismiss if appropriate

### Rules
- no dark patterns
- explain what is locked and why

---

## 15.2 Subscribe Flow

### Flow
1. User sees paywall
2. Selects plan
3. Starts trial or purchase
4. System purchase flow completes
5. Entitlement updates
6. Premium feature unlocks immediately

### Requirement
The unlock must feel instant once purchase succeeds.

---

## 15.3 Restore Purchase Flow

### Flow
1. User taps Restore Purchases
2. StoreKit restore runs
3. App verifies entitlement
4. State updates
5. Success or failure message shown

---

## 16. Empty-State Flows

## 16.1 No Progress Yet
Used on Home/Learn/Profile for brand-new users.

### Behavior
- calm explanation
- single primary CTA
- avoid overwhelming options

Example goal:
Move user into first lesson immediately.

---

## 16.2 No Search Results
Used in NEC lookup or future search.

### Behavior
- explain no result found
- suggest alternative wording
- offer Tutor as fallback if appropriate

---

## 17. Error-State Flows

## 17.1 Network Error
### Behavior
- short message
- Retry action
- preserve user context

## 17.2 Loading Failure
### Behavior
- explain what failed
- Retry
- never dump user to blank screen

## 17.3 AI Error
### Behavior
- message should be clear, not technical
- conversation remains intact
- retry available

---

## 18. Notifications / Re-entry Flow (Future-Ready)

Even before notifications are launched, WattWise should be architected for re-entry logic.

Future reminder examples:
- daily study reminder
- streak reminder
- weak-area recommendation

When user returns from a reminder, they should route to the most relevant destination:
- lesson
- quiz
- tutor
- review

---

## 19. Free vs Pro Flow Differences

### Free User Experience
- enough access to understand value
- limited tutor and/or quiz usage
- clear upgrade path
- never feels broken

### Pro User Experience
- no artificial friction
- all core learning flows fully available
- premium should feel like freedom, not just more buttons

---

## 20. Cross-Flow Rules

These rules apply everywhere:

### 20.1 Preserve Progress
Any in-progress lesson or quiz state should be preserved whenever possible.

### 20.2 Never Lose Context Unnecessarily
If a user opens Tutor from a lesson or missed question, context should carry into that session.

### 20.3 Avoid Dead Ends
Every screen should provide a logical next action.

### 20.4 Respect User Momentum
Do not over-interrupt with modals, confirmations, or upsells.

### 20.5 Home Must Always Re-Anchor the User
Home is the reset point that tells the user:
- where they left off
- what matters now
- what they should do next

---

## 21. Key Ideal Journey

This is the ideal product loop:

1. User opens WattWise
2. Home immediately presents Continue Learning
3. User resumes lesson
4. User encounters NEC concept
5. User opens explanation
6. User asks Tutor follow-up
7. User finishes lesson
8. App recommends short quiz on the same topic
9. User completes quiz
10. Results show strengths and weak points
11. User feels clear, capable, and motivated to return tomorrow

This is the experience WattWise should optimize around.

---

## 22. Definition of Flow Completion

A flow is complete when:
- the intended user outcome is achieved
- state is saved correctly
- next action is clear
- no ambiguity remains about what happened

A flow is not complete simply because a screen exists.

---

## 23. Final Principle

Every WattWise flow must reduce confusion, preserve momentum, and guide the user toward real exam readiness.

If a flow feels noisy, repetitive, or uncertain, it must be simplified before shipping.
