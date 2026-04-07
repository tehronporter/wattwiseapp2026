
# WattWise — Database Schema (Production-Level)

## 0. Purpose

This document defines the production database schema for WattWise.

It exists to ensure that:
- the Supabase/Postgres data model is clean, scalable, and secure
- product behavior maps to a clear source of truth in the database
- user data, content data, AI workflows, NEC references, progress, quizzes, and entitlements are all modeled intentionally
- engineering can implement migrations without inventing structure on the fly

This schema is designed specifically for:
- electrician apprentice exam prep
- electrician journeyman exam prep
- electrician master exam prep
- state/jurisdiction-specific preparation
- NEC code lookup and explanation
- AI tutoring
- structured lessons and quizzes
- progress tracking
- free vs Pro access controls

This document should be used alongside:
- `WATTWISE_PRD.md`
- `WATTWISE_CONTENT_STRATEGY.md`
- `WATTWISE_BACKEND_ARCHITECTURE.md`
- `WATTWISE_API_CONTRACT.md`
- `WATTWISE_AI_SYSTEM_SPEC.md`

---

## 1. Schema Design Principles

## 1.1 Clear Domain Separation
Tables must be grouped by domain:
- identity
- content
- progress
- quizzes
- tutor
- NEC
- subscriptions
- operational logging

Do not collapse unrelated concepts into vague “catch-all” tables.

## 1.2 Strong Ownership
Each important product fact should have a clear storage home.

Examples:
- user profile preferences belong in profile/preference tables
- lesson progress belongs in progress tables
- quiz outcomes belong in quiz attempt/result tables
- NEC data belongs in NEC tables
- tutor usage belongs in tutor/session tables

## 1.3 Secure by Default
All user-owned data must support RLS-safe ownership patterns.

## 1.4 Favor Explicitness Over Cleverness
A slightly more verbose schema is better than an overly magical one that becomes hard to maintain.

## 1.5 Ready for Production
The schema should support:
- reliable reads for core screens
- predictable writes
- analytics/logging
- safe evolution over time
- indexing for important queries

---

## 2. Recommended Extensions

Depending on Supabase defaults and your environment, consider enabling:

- `pgcrypto` for UUID generation if needed
- `uuid-ossp` if preferred by your migration style
- `citext` for case-insensitive email-like behavior where helpful
- `pg_trgm` for more flexible NEC/content search later
- `unaccent` if needed for text search normalization

You do not need every extension on day one, but plan intentionally.

---

## 3. Enum Types

Using explicit enums where appropriate helps consistency and prevents drift.

## 3.1 `exam_type`
Allowed values:
- `apprentice`
- `journeyman`
- `master`

Purpose:
Distinguishes learning path, quiz weighting, recommendations, and content applicability.

## 3.2 `lesson_status`
Allowed values:
- `not_started`
- `in_progress`
- `completed`

Purpose:
Tracks per-user lesson state.

## 3.3 `quiz_type`
Allowed values:
- `quick_quiz`
- `full_practice_exam`
- `weak_area_review`

Purpose:
Differentiates assessment mode.

## 3.4 `difficulty_level`
Allowed values:
- `beginner`
- `intermediate`
- `advanced`

Purpose:
Used across lessons, questions, explanations, and adaptive logic.

## 3.5 `subscription_tier`
Allowed values:
- `preview`
- `fast_track`
- `full_prep`

Purpose:
Represents current user access tier at the application level.

## 3.6 `tutor_context_type`
Allowed values:
- `general`
- `lesson`
- `quiz_review`
- `nec_detail`

Purpose:
Defines where tutor conversations originate.

## 3.7 `ai_request_type`
Allowed values:
- `tutor`
- `quiz_generation`
- `nec_explanation`
- `recommendation`
- `other`

Purpose:
Supports logging, cost analysis, and routing behavior.

## 3.8 `app_event_type`
Allowed values may begin with:
- `auth_signed_up`
- `auth_signed_in`
- `onboarding_completed`
- `lesson_started`
- `lesson_completed`
- `quiz_started`
- `quiz_submitted`
- `tutor_message_sent`
- `nec_search`
- `purchase_started`
- `purchase_restored`
- `paywall_viewed`

You may choose enum vs text + constrained event taxonomy. For fast iteration, text can be acceptable if governance is strong.

---

## 4. Domain Overview

The schema is divided into these major groups:

1. Identity & User Preferences
2. Content & Curriculum
3. NEC Domain
4. Progress & Study Activity
5. Quiz & Assessment
6. Tutor & AI Interaction
7. Subscription & Entitlements
8. Analytics & Operational Logging
9. Supporting Views / Materialized Views (optional)

---

## 5. Identity & User Preferences

## 5.1 `profiles`

### Purpose
Stores WattWise-specific user profile data beyond raw auth identity.

### Columns
- `id` UUID PRIMARY KEY
  - references `auth.users(id)` on delete cascade
- `email` TEXT NULL
  - mirrored convenience field, not the ultimate auth source
- `display_name` TEXT NULL
- `exam_type` exam_type NULL
- `jurisdiction_id` UUID NULL
  - references `jurisdictions(id)`
- `daily_study_goal_minutes` INTEGER NOT NULL DEFAULT 30
- `onboarding_completed` BOOLEAN NOT NULL DEFAULT false
- `subscription_tier` subscription_tier NOT NULL DEFAULT 'preview'
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `last_active_at` TIMESTAMPTZ NULL

### Notes
- `exam_type` and `jurisdiction_id` may be null until onboarding completes
- `subscription_tier` is an application mirror and may be derived/synced from purchase logic

### Indexes
- primary key on `id`
- index on `jurisdiction_id`
- index on `exam_type`
- index on `subscription_tier`

---

## 5.2 `study_preferences`

### Purpose
Stores user-specific preferences that affect product behavior but are not core identity.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL UNIQUE
  - references `profiles(id)` on delete cascade
- `preferred_study_mode` TEXT NULL
  - e.g. `read`, `slides`
- `preferred_quiz_length` INTEGER NULL
- `wants_daily_reminders` BOOLEAN NOT NULL DEFAULT false
- `preferred_reminder_time` TIME NULL
- `language_code` TEXT NOT NULL DEFAULT 'en'
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Indexes
- unique index on `user_id`

---

## 5.3 `jurisdictions`

### Purpose
Defines supported states/jurisdictions for exam specialization.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `code` TEXT NOT NULL UNIQUE
  - e.g. `TX`, `CA`, `NV`
- `name` TEXT NOT NULL
- `country_code` TEXT NOT NULL DEFAULT 'US'
- `is_active` BOOLEAN NOT NULL DEFAULT true
- `sort_order` INTEGER NOT NULL DEFAULT 0
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Notes
- Keep this normalized so content, quiz logic, and profiles can reference it cleanly

### Indexes
- unique index on `code`
- index on `is_active`
- index on `sort_order`

---

## 6. Content & Curriculum Domain

## 6.1 `modules`

### Purpose
Top-level curriculum units.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `slug` TEXT NOT NULL UNIQUE
- `title` TEXT NOT NULL
- `description` TEXT NULL
- `exam_type` exam_type NULL
  - nullable if shared by both apprentice and master
- `difficulty_level` difficulty_level NULL
- `sort_order` INTEGER NOT NULL
- `is_published` BOOLEAN NOT NULL DEFAULT true
- `estimated_minutes` INTEGER NULL
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Notes
- if a module is shared by both exam tracks, `exam_type` may be null and applicability can be controlled via bridge tables if needed later

### Indexes
- unique index on `slug`
- index on `sort_order`
- index on `exam_type`
- index on `is_published`

---

## 6.2 `module_jurisdictions`

### Purpose
Maps modules to jurisdictions where applicability differs.

### Columns
- `module_id` UUID NOT NULL
  - references `modules(id)` on delete cascade
- `jurisdiction_id` UUID NOT NULL
  - references `jurisdictions(id)` on delete cascade
- PRIMARY KEY (`module_id`, `jurisdiction_id`)

### Use
Only needed if not all modules are globally applicable.

### Indexes
- composite primary key already covers core query use
- optional reverse index on `jurisdiction_id`

---

## 6.3 `lessons`

### Purpose
Structured learning units inside modules.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `module_id` UUID NOT NULL
  - references `modules(id)` on delete cascade
- `slug` TEXT NOT NULL UNIQUE
- `title` TEXT NOT NULL
- `subtitle` TEXT NULL
- `summary` TEXT NULL
- `exam_type` exam_type NULL
- `difficulty_level` difficulty_level NULL
- `sort_order` INTEGER NOT NULL
- `estimated_minutes` INTEGER NULL
- `is_published` BOOLEAN NOT NULL DEFAULT true
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Indexes
- unique index on `slug`
- index on `module_id`
- index on `sort_order`
- composite index on (`module_id`, `sort_order`)
- index on `is_published`

---

## 6.4 `lesson_sections`

### Purpose
Stores structured lesson content in ordered sections/blocks.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `lesson_id` UUID NOT NULL
  - references `lessons(id)` on delete cascade
- `sort_order` INTEGER NOT NULL
- `section_type` TEXT NOT NULL
  - examples: `intro`, `body`, `example`, `callout`, `takeaway`
- `heading` TEXT NULL
- `body_markdown` TEXT NULL
- `body_plaintext` TEXT NULL
- `meta_json` JSONB NOT NULL DEFAULT '{}'::jsonb
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Notes
`meta_json` may support:
- bullet lists
- example configuration
- optional rendering hints
- future rich content references

### Indexes
- index on `lesson_id`
- composite index on (`lesson_id`, `sort_order`)

---

## 6.5 `topic_tags`

### Purpose
Normalized topics used across lessons, questions, weak-area tracking, and NEC associations.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `slug` TEXT NOT NULL UNIQUE
- `name` TEXT NOT NULL
- `description` TEXT NULL
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Examples
- `load-calculations`
- `grounding-bonding`
- `nec-210`
- `ohms-law`
- `branch-circuits`

### Indexes
- unique index on `slug`

---

## 6.6 `lesson_topic_tags`

### Purpose
Many-to-many relation between lessons and topics.

### Columns
- `lesson_id` UUID NOT NULL
  - references `lessons(id)` on delete cascade
- `topic_tag_id` UUID NOT NULL
  - references `topic_tags(id)` on delete cascade
- PRIMARY KEY (`lesson_id`, `topic_tag_id`)

---

## 6.7 `module_topic_tags` (optional)
If you want topic-level retrieval directly at module level.

### Columns
- `module_id` UUID NOT NULL
- `topic_tag_id` UUID NOT NULL
- PRIMARY KEY (`module_id`, `topic_tag_id`)

This can be skipped initially if lesson tagging is sufficient.

---

## 7. NEC Domain

## 7.1 `nec_entries`

### Purpose
Primary NEC reference records.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `reference_code` TEXT NOT NULL UNIQUE
  - e.g. `210.8`, `250.4`
- `title` TEXT NOT NULL
- `canonical_text_excerpt` TEXT NULL
- `simplified_summary` TEXT NOT NULL
- `edition` TEXT NULL
  - e.g. `2023`
- `topic_notes` TEXT NULL
- `is_active` BOOLEAN NOT NULL DEFAULT true
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Notes
- Avoid storing copyrighted material beyond what is appropriate for your rights/use model
- `canonical_text_excerpt` should be used carefully

### Indexes
- unique index on `reference_code`
- index on `is_active`

---

## 7.2 `nec_entry_topic_tags`

### Purpose
Many-to-many relation between NEC entries and topic tags.

### Columns
- `nec_entry_id` UUID NOT NULL
  - references `nec_entries(id)` on delete cascade
- `topic_tag_id` UUID NOT NULL
  - references `topic_tags(id)` on delete cascade
- PRIMARY KEY (`nec_entry_id`, `topic_tag_id`)

---

## 7.3 `lesson_nec_references`

### Purpose
Associates lessons with relevant NEC entries.

### Columns
- `lesson_id` UUID NOT NULL
  - references `lessons(id)` on delete cascade
- `nec_entry_id` UUID NOT NULL
  - references `nec_entries(id)` on delete cascade
- `display_order` INTEGER NOT NULL DEFAULT 0
- `context_note` TEXT NULL
- PRIMARY KEY (`lesson_id`, `nec_entry_id`)

### Use
Lets lesson screens render NEC references intentionally rather than embedding free-form mentions.

---

## 7.4 `nec_search_logs`

### Purpose
Stores search activity for NEC lookup usage and analytics.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL
  - references `profiles(id)` on delete cascade
- `query` TEXT NOT NULL
- `results_count` INTEGER NOT NULL DEFAULT 0
- `selected_nec_entry_id` UUID NULL
  - references `nec_entries(id)` on delete set null
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Indexes
- index on `user_id`
- index on `created_at`
- optional trigram index on `query` later if analysis/search optimization needed

---

## 7.5 `nec_explanation_requests`

### Purpose
Tracks AI-based NEC explanation expansions.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL
  - references `profiles(id)` on delete cascade
- `nec_entry_id` UUID NOT NULL
  - references `nec_entries(id)` on delete cascade
- `prompt_context` TEXT NULL
- `response_text` TEXT NULL
- `model_name` TEXT NULL
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Notes
This is useful for:
- quota tracking
- analytics
- debugging
- future explanation caching strategies

### Indexes
- index on `user_id`
- index on `nec_entry_id`
- index on `created_at`

---

## 8. Progress & Study Activity Domain

## 8.1 `lesson_progress`

### Purpose
Tracks per-user lesson state.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL
  - references `profiles(id)` on delete cascade
- `lesson_id` UUID NOT NULL
  - references `lessons(id)` on delete cascade
- `status` lesson_status NOT NULL DEFAULT 'not_started'
- `completion_percentage` NUMERIC(5,2) NOT NULL DEFAULT 0
- `last_section_index` INTEGER NULL
- `started_at` TIMESTAMPTZ NULL
- `completed_at` TIMESTAMPTZ NULL
- `last_viewed_at` TIMESTAMPTZ NULL
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Constraints
- unique (`user_id`, `lesson_id`)

### Notes
Use this table to drive:
- Continue Learning
- lesson state
- module completion aggregation

### Indexes
- unique index on (`user_id`, `lesson_id`)
- index on `user_id`
- index on `lesson_id`
- composite index on (`user_id`, `last_viewed_at` desc)

---

## 8.2 `study_activity`

### Purpose
Stores session/activity records for study time and streak logic.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL
  - references `profiles(id)` on delete cascade
- `activity_type` TEXT NOT NULL
  - examples: `lesson`, `quiz`, `tutor`, `nec`
- `source_id` UUID NULL
  - polymorphic reference handled at app/service level
- `minutes_spent` INTEGER NOT NULL DEFAULT 0
- `activity_date` DATE NOT NULL
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Notes
This table supports:
- daily goal
- streaks
- usage reporting

### Indexes
- index on `user_id`
- composite index on (`user_id`, `activity_date`)
- index on `activity_type`

---

## 8.3 `module_progress_snapshots` (optional but useful)

### Purpose
Caches module-level rollups for faster reads, if needed.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL
- `module_id` UUID NOT NULL
- `completed_lessons` INTEGER NOT NULL DEFAULT 0
- `total_lessons` INTEGER NOT NULL DEFAULT 0
- `completion_percentage` NUMERIC(5,2) NOT NULL DEFAULT 0
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Constraints
- unique (`user_id`, `module_id`)

### Notes
Can be derived instead of stored initially.
If stored, keep it strictly synced or regenerate via jobs/functions.

---

## 8.4 `streak_snapshots` (optional)
You may prefer computing streaks dynamically from `study_activity`.

### Columns
- `user_id` UUID PRIMARY KEY
- `current_streak_days` INTEGER NOT NULL DEFAULT 0
- `longest_streak_days` INTEGER NOT NULL DEFAULT 0
- `last_qualified_activity_date` DATE NULL
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

This is optional; compute dynamically first if volume is manageable.

---

## 9. Quiz & Assessment Domain

## 9.1 `question_bank`

### Purpose
Stores curated reusable questions if you maintain a static/hybrid question source.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `question_text` TEXT NOT NULL
- `choice_a` TEXT NOT NULL
- `choice_b` TEXT NOT NULL
- `choice_c` TEXT NOT NULL
- `choice_d` TEXT NOT NULL
- `correct_choice` TEXT NOT NULL
  - constrain to `A`,`B`,`C`,`D`
- `explanation` TEXT NOT NULL
- `exam_type` exam_type NULL
- `difficulty_level` difficulty_level NULL
- `jurisdiction_id` UUID NULL
  - references `jurisdictions(id)`
- `is_active` BOOLEAN NOT NULL DEFAULT true
- `source_type` TEXT NOT NULL DEFAULT 'curated'
  - examples: `curated`, `ai_generated`, `hybrid`
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Constraints
- check constraint on `correct_choice` in (`A`,`B`,`C`,`D`)

### Indexes
- index on `exam_type`
- index on `difficulty_level`
- index on `jurisdiction_id`
- index on `is_active`

---

## 9.2 `question_bank_topic_tags`

### Purpose
Many-to-many relation between questions and topics.

### Columns
- `question_id` UUID NOT NULL
  - references `question_bank(id)` on delete cascade
- `topic_tag_id` UUID NOT NULL
  - references `topic_tags(id)` on delete cascade
- PRIMARY KEY (`question_id`, `topic_tag_id`)

---

## 9.3 `quiz_attempts`

### Purpose
Represents one quiz or exam session started by a user.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL
  - references `profiles(id)` on delete cascade
- `quiz_type` quiz_type NOT NULL
- `exam_type` exam_type NOT NULL
- `jurisdiction_id` UUID NULL
  - references `jurisdictions(id)`
- `status` TEXT NOT NULL DEFAULT 'in_progress'
  - examples: `in_progress`, `submitted`, `abandoned`
- `question_count` INTEGER NOT NULL DEFAULT 0
- `correct_count` INTEGER NOT NULL DEFAULT 0
- `score_percentage` NUMERIC(5,2) NULL
- `started_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `submitted_at` TIMESTAMPTZ NULL
- `completed_at` TIMESTAMPTZ NULL
- `duration_seconds` INTEGER NULL
- `generated_by_ai` BOOLEAN NOT NULL DEFAULT false
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Indexes
- index on `user_id`
- index on `quiz_type`
- index on `status`
- composite index on (`user_id`, `started_at` desc)

---

## 9.4 `quiz_attempt_questions`

### Purpose
Stores the exact question payload used in a specific attempt, preserving integrity even if source questions later change.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `quiz_attempt_id` UUID NOT NULL
  - references `quiz_attempts(id)` on delete cascade
- `sort_order` INTEGER NOT NULL
- `question_bank_id` UUID NULL
  - references `question_bank(id)` on delete set null
- `question_text` TEXT NOT NULL
- `choice_a` TEXT NOT NULL
- `choice_b` TEXT NOT NULL
- `choice_c` TEXT NOT NULL
- `choice_d` TEXT NOT NULL
- `correct_choice` TEXT NOT NULL
- `explanation` TEXT NOT NULL
- `topic_tag_ids` UUID[] NULL
- `difficulty_level` difficulty_level NULL

### Constraints
- check `correct_choice` in (`A`,`B`,`C`,`D`)

### Notes
Snapshotting questions per attempt is strongly recommended.

### Indexes
- index on `quiz_attempt_id`
- composite index on (`quiz_attempt_id`, `sort_order`)

---

## 9.5 `quiz_attempt_answers`

### Purpose
Stores the user’s selected answers for a quiz attempt.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `quiz_attempt_question_id` UUID NOT NULL UNIQUE
  - references `quiz_attempt_questions(id)` on delete cascade
- `selected_choice` TEXT NULL
- `is_correct` BOOLEAN NULL
- `answered_at` TIMESTAMPTZ NULL

### Constraints
- check `selected_choice` is null or in (`A`,`B`,`C`,`D`)

### Notes
You can derive one answer per question from unique constraint on question row.

### Indexes
- unique index on `quiz_attempt_question_id`

---

## 9.6 `weak_topic_stats`

### Purpose
Aggregated per-user weak-area tracking.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL
  - references `profiles(id)` on delete cascade
- `topic_tag_id` UUID NOT NULL
  - references `topic_tags(id)` on delete cascade
- `attempt_count` INTEGER NOT NULL DEFAULT 0
- `incorrect_count` INTEGER NOT NULL DEFAULT 0
- `mastery_score` NUMERIC(5,2) NOT NULL DEFAULT 0
- `last_seen_at` TIMESTAMPTZ NULL
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Constraints
- unique (`user_id`, `topic_tag_id`)

### Notes
`mastery_score` can be a computed/maintained metric.
Keep the formula stable and documented in backend logic.

### Indexes
- unique index on (`user_id`, `topic_tag_id`)
- index on `user_id`
- index on `topic_tag_id`

---

## 10. Tutor & AI Interaction Domain

## 10.1 `tutor_sessions`

### Purpose
Stores high-level tutor conversation threads.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL
  - references `profiles(id)` on delete cascade
- `context_type` tutor_context_type NOT NULL DEFAULT 'general'
- `context_lesson_id` UUID NULL
  - references `lessons(id)` on delete set null
- `context_quiz_attempt_id` UUID NULL
  - references `quiz_attempts(id)` on delete set null
- `context_nec_entry_id` UUID NULL
  - references `nec_entries(id)` on delete set null
- `title` TEXT NULL
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `last_message_at` TIMESTAMPTZ NULL

### Indexes
- index on `user_id`
- index on `context_type`
- composite index on (`user_id`, `last_message_at` desc)

---

## 10.2 `tutor_messages`

### Purpose
Stores individual user and assistant messages.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `session_id` UUID NOT NULL
  - references `tutor_sessions(id)` on delete cascade
- `role` TEXT NOT NULL
  - `user` or `assistant`
- `message_text` TEXT NOT NULL
- `structured_json` JSONB NULL
- `model_name` TEXT NULL
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Constraints
- check `role` in (`user`, `assistant`)

### Notes
`structured_json` can store:
- steps
- bullets
- citations/anchors
- UI rendering hints

### Indexes
- index on `session_id`
- composite index on (`session_id`, `created_at`)

---

## 10.3 `ai_request_logs`

### Purpose
Tracks AI workload, cost analysis, and operational debugging across tutor, NEC, and quiz generation.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NULL
  - references `profiles(id)` on delete set null
- `request_type` ai_request_type NOT NULL
- `related_session_id` UUID NULL
- `related_quiz_attempt_id` UUID NULL
- `related_nec_entry_id` UUID NULL
- `provider_name` TEXT NULL
- `model_name` TEXT NULL
- `status` TEXT NOT NULL
  - e.g. `success`, `error`, `rate_limited`
- `input_tokens` INTEGER NULL
- `output_tokens` INTEGER NULL
- `estimated_cost_usd` NUMERIC(12,6) NULL
- `error_code` TEXT NULL
- `error_message` TEXT NULL
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Indexes
- index on `user_id`
- index on `request_type`
- index on `status`
- index on `created_at`

---

## 10.4 `ai_usage_counters` (optional)
If you want quick quota reads instead of scanning logs.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL
- `usage_date` DATE NOT NULL
- `request_type` ai_request_type NOT NULL
- `request_count` INTEGER NOT NULL DEFAULT 0
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Constraints
- unique (`user_id`, `usage_date`, `request_type`)

This can simplify preview quota enforcement.

---

## 11. Subscription & Entitlement Domain

## 11.1 `subscription_statuses`

### Purpose
Stores mirrored access state for backend awareness.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL UNIQUE
  - references `profiles(id)` on delete cascade
- `tier` subscription_tier NOT NULL DEFAULT 'preview'
- `store_product_id` TEXT NULL
- `store_transaction_id` TEXT NULL
- `store_original_transaction_id` TEXT NULL
- `status` TEXT NOT NULL DEFAULT 'inactive'
  - examples: `inactive`, `active`, `expired`
- `current_period_start` TIMESTAMPTZ NULL
- `current_period_end` TIMESTAMPTZ NULL
- `last_verified_at` TIMESTAMPTZ NULL
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Notes
This is a mirror of preview, Fast Track, and Full Prep access, not a replacement for on-device StoreKit truth.

### Indexes
- unique index on `user_id`
- index on `tier`
- index on `status`

---

## 11.2 `purchase_events`

### Purpose
Audit trail of purchase-related events observed/synced by the backend.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NULL
  - references `profiles(id)` on delete set null
- `event_type` TEXT NOT NULL
  - examples: `purchase_started`, `purchase_completed`, `restore_requested`, `restore_completed`, `verification_failed`
- `store_product_id` TEXT NULL
- `store_transaction_id` TEXT NULL
- `payload_json` JSONB NOT NULL DEFAULT '{}'::jsonb
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Indexes
- index on `user_id`
- index on `event_type`
- index on `created_at`

---

## 12. Analytics & Operational Logging

## 12.1 `app_events`

### Purpose
Stores product usage events useful for analytics and debugging.

### Columns
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NULL
  - references `profiles(id)` on delete set null
- `event_type` TEXT NOT NULL
- `event_properties` JSONB NOT NULL DEFAULT '{}'::jsonb
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Notes
This table should be curated, not spammed.
Only important events belong here.

### Indexes
- index on `user_id`
- index on `event_type`
- index on `created_at`

---

## 12.2 `feature_flags`

### Purpose
Supports controlled rollout/configuration toggles.

### Columns
- `key` TEXT PRIMARY KEY
- `enabled` BOOLEAN NOT NULL DEFAULT false
- `payload_json` JSONB NOT NULL DEFAULT '{}'::jsonb
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Examples
- `nec_ai_expansion_enabled`
- `full_exam_mode_enabled`
- `free_quiz_limit_per_day`

---

## 12.3 `operational_settings`

### Purpose
Stores central configurable settings without creating scattered magic constants.

### Columns
- `key` TEXT PRIMARY KEY
- `value_json` JSONB NOT NULL DEFAULT '{}'::jsonb
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()

### Examples
- daily free tutor quota
- recommended quiz length defaults
- maintenance messages

---

## 13. Optional Views / Derived Read Models

These are not required initially, but are often useful.

## 13.1 `vw_user_home_summary`

### Purpose
A read model for Home screen summary data.

Could expose:
- current streak
- daily goal progress
- continue learning lesson
- last module progress
- recommendation hints

This can simplify the Home endpoint.

---

## 13.2 `vw_module_progress`

### Purpose
Aggregates module completion per user from lesson_progress.

Could expose:
- completed lessons
- total lessons
- percentage complete

---

## 13.3 `vw_weak_topics_ranked`

### Purpose
Returns weakest topics for a given user ordered by mastery score / incorrect count.

---

## 14. Foreign Key & Delete Strategy

## 14.1 Use `ON DELETE CASCADE` for user-owned child records
Examples:
- profile → study_preferences
- profile → lesson_progress
- profile → quiz_attempts
- tutor_sessions → tutor_messages

This keeps cleanup consistent.

## 14.2 Use `ON DELETE SET NULL` where historical logging should survive
Examples:
- logs pointing to now-removed related entities
- purchase and AI logs where the user or related content may later be removed

## 14.3 Protect Core Reference Data
Reference content tables such as:
- modules
- lessons
- topic_tags
- nec_entries
should not be casually deleted in production.
Favor soft operational discipline or status flags over destructive deletes.

---

## 15. RLS Considerations by Table

## 15.1 User-Owned Tables
These should be readable/writable only by the owning user:
- profiles
- study_preferences
- lesson_progress
- study_activity
- quiz_attempts
- quiz_attempt_questions
- quiz_attempt_answers
- weak_topic_stats
- tutor_sessions
- tutor_messages
- nec_search_logs
- nec_explanation_requests
- subscription_statuses
- purchase_events
- app_events (if user-scoped)
- ai_request_logs (possibly restricted more tightly)

## 15.2 Shared Reference Tables
These may be readable to authenticated users:
- jurisdictions
- modules
- module_jurisdictions
- lessons
- lesson_sections
- topic_tags
- lesson_topic_tags
- nec_entries
- nec_entry_topic_tags
- lesson_nec_references
- question_bank
- question_bank_topic_tags
- feature_flags / operational_settings may be accessed only through backend or restricted views

## 15.3 Recommendation
Use direct table access sparingly for sensitive workflows.
For complex logic, rely on edge functions.

---

## 16. Suggested SQL Constraint Rules

Examples to implement:
- non-negative checks on `daily_study_goal_minutes`
- non-negative checks on `minutes_spent`
- percentage ranges (`completion_percentage`, `score_percentage`, `mastery_score`) constrained between 0 and 100 where applicable
- answer choice checks for `A/B/C/D`
- reasonable uniqueness constraints on one-row-per-user patterns
- timestamps defaulted to `now()`

Constraints matter because they keep bad state out of the system before bugs spread.

---

## 17. Timestamp Strategy

All mutable production tables should include:
- `created_at`
- `updated_at` where relevant

Update-heavy tables should use a trigger or application logic to maintain `updated_at`.

Important activity tables may also include:
- `last_viewed_at`
- `last_message_at`
- `submitted_at`
- `completed_at`

Use explicit event timestamps instead of trying to infer everything from `updated_at`.

---

## 18. Recommended Migration Order

A clean migration sequence helps avoid dependency issues.

Suggested order:

1. extensions and enums
2. jurisdictions
3. profiles
4. study_preferences
5. modules
6. module_jurisdictions
7. lessons
8. lesson_sections
9. topic_tags
10. lesson_topic_tags
11. nec_entries
12. nec_entry_topic_tags
13. lesson_nec_references
14. question_bank
15. question_bank_topic_tags
16. lesson_progress
17. study_activity
18. module_progress_snapshots / streak_snapshots (if used)
19. quiz_attempts
20. quiz_attempt_questions
21. quiz_attempt_answers
22. weak_topic_stats
23. tutor_sessions
24. tutor_messages
25. nec_search_logs
26. nec_explanation_requests
27. ai_request_logs
28. ai_usage_counters (if used)
29. subscription_statuses
30. purchase_events
31. app_events
32. feature_flags
33. operational_settings
34. views / indexes / policies / triggers

---

## 19. Initial Seed Data Recommendations

At minimum, seed:
- jurisdictions
- modules
- lessons
- topic tags
- NEC entries
- some curated question bank rows
- feature flags / operational settings defaults

Do not launch with an empty content layer.

---

## 20. Tables You Can Skip Initially If Needed

To simplify v1, these are optional:
- `module_progress_snapshots`
- `streak_snapshots`
- `ai_usage_counters`
- `module_topic_tags`

You can derive or compute these initially.

However, do **not** skip the core tables that define:
- profiles
- jurisdictions
- modules
- lessons
- NEC entries
- lesson progress
- quiz attempts
- tutor sessions/messages
- subscription status

---

## 21. Recommended Indexing Priorities

High-priority indexes:
- `profiles(id)`
- `profiles(jurisdiction_id)`
- `modules(sort_order)`
- `lessons(module_id, sort_order)`
- `lesson_progress(user_id, lesson_id)`
- `lesson_progress(user_id, last_viewed_at desc)`
- `quiz_attempts(user_id, started_at desc)`
- `tutor_sessions(user_id, last_message_at desc)`
- `nec_entries(reference_code)`
- `weak_topic_stats(user_id, topic_tag_id)`
- `study_activity(user_id, activity_date)`

Do not over-index blindly, but prioritize the reads that power:
- Home
- Learn
- Continue Learning
- Progress
- Tutor history
- NEC lookup

---

## 22. Data Retention Considerations

Decide early how long to keep:
- tutor messages
- AI logs
- app events
- NEC search logs

Recommended principles:
- keep core user progress long-term
- keep tutor history as long as product value justifies it
- prune or archive noisy operational logs if needed
- retain enough logging to debug subscription, AI, and quiz issues

---

## 23. Soft Delete Considerations

For v1, many core content tables may not need soft delete if content operations are tightly controlled.

If you expect frequent content editing or admin tools later, consider soft-delete support for:
- modules
- lessons
- question bank entries
- NEC entries

User-owned progress and attempts generally should not be soft-deleted unless there is a very specific product need.

---

## 24. Example “Minimal Viable Production Schema” Subset

If building in the leanest viable order, the absolute production core is:

- profiles
- study_preferences
- jurisdictions
- modules
- lessons
- lesson_sections
- topic_tags
- lesson_topic_tags
- nec_entries
- lesson_nec_references
- question_bank
- question_bank_topic_tags
- lesson_progress
- study_activity
- quiz_attempts
- quiz_attempt_questions
- quiz_attempt_answers
- weak_topic_stats
- tutor_sessions
- tutor_messages
- subscription_statuses
- app_events
- feature_flags
- operational_settings

This subset is enough to power a serious v1.

---

## 25. Anti-Patterns to Avoid

Do not:
- store all lesson content in one giant unstructured blob when sections matter
- store user progress in vague JSON instead of normalized progress rows
- rely on app-side-only calculation for quiz truth
- mix NEC entries into generic free-text notes with no structure
- collapse tutor logs, AI logs, and user messages into one table
- use subscription flags with no mirrored record or reconciliation path
- overstuff every table with JSON when proper columns are clearer

---

## 26. Final Schema Principle

The WattWise schema should make the product more trustworthy, not more fragile.

A user should be able to:
- choose their state
- follow structured lessons
- understand NEC references
- practice intelligently
- ask the tutor for help
- see real progress
- upgrade confidently

That experience only works when the database is disciplined, explicit, and stable underneath.
