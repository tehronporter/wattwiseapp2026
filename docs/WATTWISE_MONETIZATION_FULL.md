
# WattWise — Monetization Strategy (Production-Level)

## 0. Purpose

This document defines the monetization system for WattWise.

It exists to ensure that:
- the business model is clear before implementation
- free vs Pro boundaries are intentional
- subscriptions support long-term revenue without damaging trust
- paywall placement feels natural, not manipulative
- engineering, product, and design align on what is gated, what is free, and why

WattWise monetization must support a sustainable product business while preserving the app’s core identity as a calm, trustworthy study companion.

---

## 1. Monetization Philosophy

## 1.1 Value Before Friction
Users must experience meaningful value before being heavily gated.

WattWise should never feel broken on free.
It should feel useful on free, and significantly more powerful on Pro.

## 1.2 Trust Over Tricks
No dark patterns.
No fake urgency.
No deceptive restore flows.
No confusing subscription language.

## 1.3 Premium = More Capability, Not More Noise
Pro should unlock deeper learning power:
- more access
- more support
- more continuity
- more intelligent study tools

It should not unlock random cosmetic extras.

## 1.4 Respect the Study Experience
The user is likely preparing for a real licensing exam under real pressure.
Monetization must respect that context.

---

## 2. Core Revenue Model

WattWise will use a subscription model.

### Supported Tiers
- Free
- Pro

### Initial Paid Products
Recommended:
- Monthly Pro
- Annual Pro

Optional later:
- introductory offer
- free trial
- regional pricing strategy
- limited promotional offer codes

---

## 3. What the User Is Paying For

The user is not paying simply to “use AI.”
They are paying for a more complete study system.

WattWise Pro should be positioned as unlocking:

- unlimited AI tutoring
- more practice access
- deeper review tools
- richer exam preparation support
- less friction in daily study

The emotional value is:
- confidence
- consistency
- clarity
- readiness

---

## 4. Free Tier Strategy

## 4.1 Purpose of Free Tier
The free tier should:
- allow users to understand the product
- demonstrate real usefulness
- support habit formation
- create trust
- naturally lead serious users toward Pro

## 4.2 Free Tier Must Include
At minimum, free users should have access to:
- account creation and onboarding
- exam type and state setup
- access to core app shell
- a limited portion of structured learning content
- limited quiz access
- limited AI tutor usage
- Home, Learn, basic Progress, and Profile views
- NEC lookup access in a limited or guided form, depending on final gating model

## 4.3 Free Tier Must Not Feel Broken
Users should still be able to:
- start learning
- understand the app’s value
- feel guided
- complete meaningful study actions

If free feels too restricted, trust and conversion both suffer.

---

## 5. Pro Tier Strategy

## 5.1 Purpose of Pro
Pro exists for users who are serious about passing their exam and want the full WattWise study system.

## 5.2 Pro Should Unlock
Recommended Pro access includes:

### AI Tutor
- unlimited or much higher usage
- contextual explanations
- quiz mistake review support
- NEC follow-up explanations

### Practice System
- unlimited quick quizzes
- full practice exams
- advanced weak-area review

### Learning Depth
- full access to all lessons/modules
- full state-specific curriculum depth
- advanced explanations

### NEC Intelligence
- richer NEC explanation flows
- deeper AI-assisted code understanding
- more frequent NEC explain requests

### Progress & Review
- more complete weak-area tracking
- advanced readiness visibility later
- richer historical review access if introduced

---

## 6. Recommended Feature Gating

Below is the recommended initial gating model.

## 6.1 Free User Access

### Included
- onboarding
- exam type selection
- state selection
- Home screen
- module browsing
- limited lesson access
- limited daily quiz usage
- limited tutor messages
- basic NEC lookup
- progress summary
- profile/settings

### Limited
- AI tutor usage per day or per month
- quick quizzes per day
- number of full lessons unlocked
- advanced NEC explanation expansions
- full practice exam access

### Excluded / Pro Only
- unlimited tutor access
- unlimited quizzes
- full practice exams
- deeper weak-area review tools
- full curriculum unlock

---

## 6.2 Pro User Access

### Included
- full curriculum
- unlimited or high-limit AI tutor
- unlimited quick quizzes
- full practice exams
- full weak-area review
- deeper NEC explanation support
- all currently supported exam prep features

### Principle
Pro removes serious study friction.

---

## 7. Recommended Initial Gating Rules

These rules are recommendations and can be tuned later.

## 7.1 Tutor Gating
Free:
- limited tutor messages per day or month
- enough to demonstrate clear value

Pro:
- unlimited or very high usage cap

Why:
Tutor is one of WattWise’s strongest premium differentiators.

## 7.2 Quiz Gating
Free:
- limited quick quizzes
- little or no full practice exam access

Pro:
- unlimited quick quizzes
- full practice exams enabled

Why:
Practice volume is a high-intent monetization lever.

## 7.3 Lesson Gating
Free:
- enough lessons/modules to create real product understanding
- avoid completely hollow free experience

Pro:
- full learning path unlocked

Why:
If users cannot feel content quality, they will not upgrade.

## 7.4 NEC Gating
Free:
- basic NEC search and summaries
- limited AI “Explain Further” usage

Pro:
- deeper and more frequent NEC explanation support

Why:
NEC is a strong differentiator and premium-value area.

---

## 8. Paywall Placement Strategy

Paywall placement must feel contextual and justified.

## 8.1 Primary Paywall Entry Points

### 1. Usage Limits Reached
Examples:
- tutor quota reached
- quiz limit reached
- NEC AI explanation limit reached

This is the strongest placement because intent is already present.

### 2. Locked Advanced Feature Access
Examples:
- full practice exam
- full weak-area review
- advanced lesson access

### 3. Optional Upgrade Entry from Profile
For users already exploring the product and wanting more information.

---

## 8.2 Avoid Overuse
Do not constantly interrupt the user with upsells.
Do not trigger a paywall simply for app navigation curiosity.

The best paywalls appear when:
- value is clear
- intent is high
- restriction is understandable

---

## 9. Paywall UX Principles

## 9.1 Clear Value
The paywall must explain:
- what is unlocked
- why it matters
- what the user can do with it

## 9.2 Calm Design
Use TEHSO principles:
- white-dominant layout
- single accent color
- clean hierarchy
- clear restore purchase option
- no aggressive red countdowns or fake scarcity

## 9.3 Honest Copy
Use copy like:
- “Unlock unlimited tutoring and full practice exams”
- “Get the full WattWise study system”
- “Study with fewer limits”

Avoid copy like:
- “Act now”
- “Last chance”
- “Only today” unless factually true

---

## 10. StoreKit Product Strategy

## 10.1 Recommended Product IDs
Examples:
- `wattwise.pro.monthly`
- `wattwise.pro.yearly`

Use a clean naming convention and do not create unnecessary product ID clutter.

## 10.2 Initial Offering Strategy
Recommended:
- monthly plan
- annual plan with visible savings
- optional free trial if economics and App Store strategy support it

## 10.3 Restore Purchases
Must be clearly accessible:
- on paywall
- in Profile / Settings

Restore flow must be reliable and easy to understand.

---

## 11. Trial Strategy

## 11.1 Whether to Use a Trial
A free trial can help conversion, but only if:
- the premium value is clear
- the unlock feels meaningful
- the user is likely to engage immediately

## 11.2 Recommended Trial Option
If used:
- 7-day free trial on annual or monthly plan

## 11.3 Risks
Do not rely on the trial to hide a weak free experience.
Free must still be valuable on its own.

---

## 12. Entitlement Strategy

## 12.1 Product Logic
The app should think in terms of entitlements, not raw purchase strings.

Questions the app should be able to answer:
- can user access tutor?
- can user generate another quiz?
- can user open full practice exam?
- should paywall be shown?

## 12.2 Device + Backend Reconciliation
On device:
- StoreKit 2 verifies subscription state

On backend:
- mirrored subscription state may support
  - AI quota enforcement
  - analytics
  - cross-session awareness

## 12.3 Rule
Premium access should unlock promptly after successful purchase.
Do not make the user wait on backend propagation to feel upgraded.

---

## 13. AI Cost and Monetization Alignment

Tutor and NEC AI features directly influence operating cost.

This means:
- free tier should be generous but controlled
- premium tier should support heavier usage
- backend quotas should align with unit economics

If AI costs rise, the backend can tune:
- quota limits
- model routing
- output length
without forcing app redesign

---

## 14. Monetization Copy Framework

## 14.1 Core Message
WattWise Pro helps you study with fewer limits and more confidence.

## 14.2 Value Pillars for Paywall
Recommended benefits list:
- Unlimited AI tutor help
- Full practice exams
- More quiz access
- Deeper NEC explanations
- Full learning path access

## 14.3 Tone
Calm, direct, useful.
No hype.
No fear-based pressure.

---

## 15. Monetization Event Tracking

Track key monetization events:

- paywall viewed
- plan selected
- purchase started
- purchase completed
- restore started
- restore completed
- purchase failed
- paywall dismissed
- premium feature gate hit

This supports:
- conversion analysis
- paywall iteration
- support debugging

---

## 16. Recommended Pricing Structure

Exact pricing is a business decision, but structure should generally favor:
- accessible monthly option
- stronger annual value for committed users

Recommended pattern:
- Monthly Pro
- Annual Pro (best value)

Make sure pricing presentation is:
- clear
- localized through App Store
- visually balanced
- not overwhelming

---

## 17. Free-to-Paid Conversion Strategy

The best conversion path is not “show bigger paywalls.”
It is:

1. user gets real value
2. user builds habit
3. user encounters meaningful limit
4. paywall explains why Pro matters
5. user upgrades because it makes sense

This means the product itself is the sales engine.

---

## 18. Churn & Retention Considerations

Monetization is not only about conversion. It is also about retention.

To reduce churn:
- make Pro feel clearly useful
- unlock capabilities that support daily study
- avoid confusing entitlement bugs
- keep free users warm without making them feel punished
- ensure subscription state is always accurate

---

## 19. Support Considerations

Customer support and trust depend heavily on purchase clarity.

Minimum support-ready flows:
- restore purchases
- clear subscription status in profile
- graceful handling of expired subscriptions
- no contradictory premium states
- useful purchase failure messages

---

## 20. Future Monetization Opportunities (Within Scope)

Potential later opportunities within the electrician-only roadmap:
- specialized state packs if strategically useful
- advanced exam simulation tiering
- institution / school licenses later
- promotional offer codes
- annual bundles with premium readiness tools

These should only be explored if they do not complicate the core subscription model too early.

---

## 21. Things WattWise Should Not Monetize

Do not monetize in ways that feel exploitative or low-trust.

Avoid:
- charging separately for basic NEC lookup if it breaks the product
- over-fragmenting features into micro-purchases
- multiple overlapping subscription tiers too early
- restricting so much free value that the app feels unusable
- aggressive interruption-based upselling

WattWise should feel premium, not predatory.

---

## 22. Definition of Monetization Done

The monetization system is correctly implemented when:
- free users can experience real value
- Pro users feel genuinely unlocked
- paywall placement is contextual
- restore flow works reliably
- subscription state is accurate
- backend quotas align with tier logic
- pricing copy is clear
- monetization supports the product instead of harming trust

---

## 23. Final Monetization Principle

WattWise should make money because it helps people study better, not because it pressures them harder.

The strongest monetization system for WattWise is one that feels:
- fair
- useful
- premium
- calm
- trustworthy
