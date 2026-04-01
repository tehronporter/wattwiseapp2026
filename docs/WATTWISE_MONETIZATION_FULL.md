# WattWise — Monetization Strategy (Production-Level)

## 0. Purpose

This document defines the production monetization system for WattWise.

It exists to ensure:
- the product sells serious exam-prep access, not generic premium features
- preview limits feel intentional, not broken
- paid access is clear, calm, and trustworthy
- iOS, backend, design, and QA all implement the same access model

WattWise monetization must feel aligned with real electrician exam prep:
- practical
- credible
- direct
- fair

---

## 1. Core Monetization Model

WattWise uses a guided preview plus two paid access offers.

### Access States
- `preview`
- `fast_track`
- `full_prep`

### Paid Offers
- Fast Track
- $69
- 3 months access
- best for focused, fast prep

- Full Prep
- $119
- full access until you pass, up to 12 months
- best for serious candidates who want the strongest runway

### Positioning Rule
Do not position WattWise as:
- a monthly subscription
- an annual subscription
- a free trial funnel
- a generic “upgrade to Pro” flow

Position it as:
- exam prep access
- your full prep system
- serious preparation with fewer limits and more confidence

---

## 2. Monetization Philosophy

### 2.1 Value Before Friction
Users must feel real product value before they hit a gate.

### 2.2 Trust Over Tactics
No fake urgency.
No manipulative countdowns.
No noisy discount gimmicks.
No dark patterns.

### 2.3 Calm, Serious Framing
WattWise should feel closer to a prep course or trade tool than a lifestyle app.

### 2.4 The User Pays for Outcomes
The user is paying for:
- clearer study structure
- better exam practice
- faster recovery when stuck
- stronger confidence before test day

---

## 3. Preview Strategy

Preview is not an open-ended free tier.
It is a meaningful, guided product preview.

### Preview Includes
- onboarding
- exam type and state setup
- Home, Learn, Practice, Tutor, NEC, and Profile surfaces
- 1 full lesson
- 1 quick quiz
- full quiz results for that preview quiz
- 4 tutor questions
- 1 NEC explanation sample if NEC explain is available
- visibility into locked lessons and deeper practice paths

### Preview Must Feel Useful
The preview should let a serious user:
- see lesson quality
- complete one full learning loop
- feel the tutor’s value
- understand how deeper study would work with full access

### Preview Must Not Allow
- unlimited lesson access
- repeat quiz generation
- full practice exams
- unlimited tutor usage
- unlimited NEC explanation usage
- deeper weak-area review beyond the preview path

---

## 4. Paid Access Strategy

### 4.1 Fast Track
Fast Track is the shorter paid option for focused candidates.

It includes:
- full lesson access
- full quiz access
- full practice exam access
- weak-area review
- tutor access without preview caps
- NEC explanation access without preview caps

### 4.2 Full Prep
Full Prep is the primary recommendation.

It includes:
- the full WattWise prep system
- the longest access window
- the clearest “serious candidate” positioning
- the strongest confidence framing

### 4.3 Recommendation Rule
Full Prep should be the default recommended offer in the paywall UI, but in a calm TEHSO way.

Use:
- slightly stronger visual hierarchy
- a “Recommended” treatment
- stronger primary CTA wording

Do not use:
- fake discounts
- “today only”
- strikethrough pricing theatrics

---

## 5. Product Gating Rules

### 5.1 Lesson Access
Preview:
- first full lesson only

Paid:
- full curriculum

### 5.2 Quiz Access
Preview:
- 1 quick quiz
- full results breakdown for that quiz

Paid:
- repeated quick quizzes
- full practice exams
- weak-area review

### 5.3 Tutor Access
Preview:
- 4 tutor questions total

Paid:
- tutor access without preview caps

### 5.4 NEC Access
Preview:
- NEC browsing/search remains visible if implemented
- 1 NEC explanation sample

Paid:
- NEC explanation access without preview caps

### 5.5 Navigation Rule
Locked content should never lead to a blank screen or dead end.

Every gate must provide:
- a clear explanation
- a clear access CTA
- a meaningful path back

---

## 6. Paywall Placement Strategy

Paywalls should appear at high-intent moments only.

### Primary Entry Points
- after the preview quick quiz results when the user wants the next step
- when the user tries to open lesson 2 or deeper content
- when the user tries to generate another quiz beyond preview
- when the user tries to start a full practice exam
- when the user tries to start weak-area review
- when preview tutor questions are exhausted
- when preview NEC explanation usage is exhausted
- when the user opens access options from Profile or Home

### Avoid
- immediate first-open interruption
- random paywall presentation
- blocking curiosity before value is shown

---

## 7. Paywall Copy Framework

### Core Headline Direction
- Unlock your full exam prep system
- Study with more confidence
- Get everything you need to prepare seriously

### Value Pillars
- full lesson access
- more practice quizzes and exam sessions
- tutor help when you get stuck
- NEC explanations made simpler
- state-aware study support

### Tone
- calm
- direct
- credible
- respectful

Avoid:
- “Subscribe now”
- “Unlock premium”
- “Start free trial”
- generic SaaS language

---

## 8. StoreKit Product Strategy

### Product IDs
- `wattwise.fasttrack.3month`
- `wattwise.fullprep.12month`

### Product Behavior
The app should think in terms of access entitlements, not raw StoreKit strings.

### Restore
Restore must remain available:
- on the paywall
- in Profile

Restore copy should speak in terms of access, not subscriptions.

---

## 9. Entitlement Strategy

The app should answer these questions directly:
- can this user open this lesson?
- can this user start another quick quiz?
- can this user start a full practice exam?
- can this user ask another tutor question?
- should a paywall be shown here?
- which paywall context copy should appear?

### Required Entitlement Fields
- `tier`
- `status`
- `expires_at`
- `store_product_id`
- `preview_quizzes_used`
- `preview_quizzes_limit`
- `tutor_messages_used`
- `tutor_messages_limit`
- `nec_explanations_used`
- `nec_explanations_limit`

### Rule
Paid access should feel unlocked immediately after successful purchase.

---

## 10. Backend Mirroring

Backend mirrored access state exists to support:
- reliable AI access checks
- paywall and usage analytics
- restore and reconciliation behavior
- future operational tuning

The backend must not assume monthly or yearly subscriptions.
It must understand:
- preview
- fast_track
- full_prep

---

## 11. Monetization Event Tracking

Track at minimum:
- paywall viewed
- paywall context
- offer selected
- purchase started
- purchase completed
- purchase failed
- restore started
- restore completed
- paywall dismissed
- preview limit reached

---

## 12. Definition of Monetization Done

Monetization is done when:
- preview feels valuable and coherent
- paid access feels clear and fair
- Fast Track and Full Prep are correctly represented everywhere
- no stale Pro/monthly/yearly framing remains in product-critical UI
- restore works reliably
- access checks are consistent across iOS and backend
- paywalls only appear at intentional moments
- locked states explain the next step clearly

---

## 13. Final Principle

WattWise should make money because it helps electricians prepare seriously and pass with more confidence, not because it pressures them with generic subscription tactics.
