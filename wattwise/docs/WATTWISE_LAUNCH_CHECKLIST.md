# WattWise Launch Checklist

## Product truth
- Lessons, quizzes, flashcards, glossary, quick references, and study plans are all exported from published content only.
- Bundle copy and in-app copy describe WattWise as national NEC-first prep with verified state-aware guidance where available.
- Every shipped lesson surfaces code cycle, jurisdiction scope, freshness, and last-verified metadata when available.

## Auth and access
- Email sign-up, confirmation, sign-in, password reset, Apple Sign-In, sign-out, and account deletion all work on device.
- Preview, Fast Track, Full Prep, expired access, and restore purchases behave consistently across paywall and backend.
- No customer-facing learn/practice gating depends on draft content or mock-only assumptions.

## Content readiness
- `node wattwise/scripts/repair_content_pack.cjs`
- `node wattwise/scripts/validate_content_pipeline.cjs`
- `node wattwise/scripts/content_readiness_report.cjs`
- `node wattwise/scripts/generate_content_seed.cjs`
- Readiness score meets the launch target and no published lessons/questions fail validation.

## Operations
- `track_client_event` and `delete_account` are deployed.
- Production analytics events are visible in Supabase `client_events`.
- API failures, auth failures, and purchase issues generate visible runtime events.
- Support email, privacy policy, and terms links are live.

## Manual QA
- First-time preview user
- Returning authenticated user
- Paid user with active access
- Expired or restored purchase
- Weak network / retry states
- Lesson completion and resume
- Quiz start / submit / results
- Tutor usage and quota limit
- NEC search / explain and quota limit
- Account deletion flow

## App Store readiness
- Privacy policy URL
- Terms URL
- Support URL
- Updated screenshots and description
- Subscription disclosure reviewed
- Sign in with Apple capability enabled
