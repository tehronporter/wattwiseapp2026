-- WattWise content pipeline hardening
-- Adds profile bootstrap, backfill, read-path indexes, and data-integrity constraints

BEGIN;

CREATE OR REPLACE FUNCTION public.handle_new_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    onboarding_completed,
    created_at,
    updated_at,
    last_active_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    false,
    now(),
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE
    SET email = COALESCE(EXCLUDED.email, public.profiles.email),
        last_active_at = now(),
        updated_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created_wattwise_profile ON auth.users;

CREATE TRIGGER on_auth_user_created_wattwise_profile
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user_profile();

INSERT INTO public.profiles (
  id,
  email,
  onboarding_completed,
  created_at,
  updated_at,
  last_active_at
)
SELECT
  users.id,
  users.email,
  false,
  now(),
  now(),
  now()
FROM auth.users AS users
LEFT JOIN public.profiles AS profiles
  ON profiles.id = users.id
WHERE profiles.id IS NULL;

CREATE INDEX IF NOT EXISTS idx_module_topic_tags_topic_id
  ON module_topic_tags(topic_tag_id);

CREATE INDEX IF NOT EXISTS idx_lesson_nec_references_lesson_id
  ON lesson_nec_references(lesson_id);

CREATE INDEX IF NOT EXISTS idx_nec_search_index_search_text_gin
  ON nec_search_index
  USING GIN (to_tsvector('simple', search_text));

CREATE UNIQUE INDEX IF NOT EXISTS idx_lesson_sections_lesson_sort_unique
  ON lesson_sections(lesson_id, sort_order);

ALTER TABLE lesson_progress
  DROP CONSTRAINT IF EXISTS lesson_progress_completion_percentage_range;

ALTER TABLE lesson_progress
  ADD CONSTRAINT lesson_progress_completion_percentage_range
  CHECK (completion_percentage >= 0 AND completion_percentage <= 100);

ALTER TABLE modules
  DROP CONSTRAINT IF EXISTS modules_sort_order_positive;

ALTER TABLE modules
  ADD CONSTRAINT modules_sort_order_positive
  CHECK (sort_order > 0);

ALTER TABLE lessons
  DROP CONSTRAINT IF EXISTS lessons_sort_order_positive;

ALTER TABLE lessons
  ADD CONSTRAINT lessons_sort_order_positive
  CHECK (sort_order > 0);

ALTER TABLE lesson_sections
  DROP CONSTRAINT IF EXISTS lesson_sections_sort_order_positive;

ALTER TABLE lesson_sections
  ADD CONSTRAINT lesson_sections_sort_order_positive
  CHECK (sort_order > 0);

ALTER TABLE study_sessions
  DROP CONSTRAINT IF EXISTS study_sessions_total_minutes_nonnegative;

ALTER TABLE study_sessions
  ADD CONSTRAINT study_sessions_total_minutes_nonnegative
  CHECK (total_minutes >= 0);

ALTER TABLE daily_study_goals
  DROP CONSTRAINT IF EXISTS daily_study_goals_minutes_nonnegative;

ALTER TABLE daily_study_goals
  ADD CONSTRAINT daily_study_goals_minutes_nonnegative
  CHECK (minutes_completed >= 0 AND target_minutes > 0);

ALTER TABLE module_topic_tags DISABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_topic_tags DISABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_nec_references DISABLE ROW LEVEL SECURITY;
ALTER TABLE nec_search_index DISABLE ROW LEVEL SECURITY;
ALTER TABLE nec_entry_topic_tags DISABLE ROW LEVEL SECURITY;

COMMIT;
