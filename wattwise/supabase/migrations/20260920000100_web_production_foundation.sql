BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS exam_date DATE NULL,
  ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'America/Los_Angeles';

DROP POLICY IF EXISTS "Users can insert own study preferences" ON public.study_preferences;
CREATE POLICY "Users can insert own study preferences" ON public.study_preferences
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own study preferences" ON public.study_preferences;
CREATE POLICY "Users can update own study preferences" ON public.study_preferences
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.lesson_bookmarks (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, lesson_id)
);

ALTER TABLE public.lesson_bookmarks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own lesson bookmarks" ON public.lesson_bookmarks;
CREATE POLICY "Users manage own lesson bookmarks" ON public.lesson_bookmarks
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.quizzes
  ADD COLUMN IF NOT EXISTS user_id UUID NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS topic_tags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS source TEXT NULL;

CREATE INDEX IF NOT EXISTS idx_quizzes_user_id ON public.quizzes(user_id);

CREATE TABLE IF NOT EXISTS public.question_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quiz_attempt_id UUID NOT NULL REFERENCES public.quiz_attempts(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES public.practice_questions(id) ON DELETE RESTRICT,
  selected_choice TEXT NULL,
  is_correct BOOLEAN NOT NULL DEFAULT false,
  response_ms INTEGER NULL CHECK (response_ms IS NULL OR response_ms >= 0),
  flagged BOOLEAN NOT NULL DEFAULT false,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (quiz_attempt_id, question_id)
);

CREATE INDEX IF NOT EXISTS idx_question_attempts_user_topic_lookup
  ON public.question_attempts(user_id, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_question_attempts_question
  ON public.question_attempts(question_id, submitted_at DESC);

ALTER TABLE public.question_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users view own question attempts" ON public.question_attempts;
CREATE POLICY "Users view own question attempts" ON public.question_attempts
  FOR SELECT USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.topic_mastery (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  topic_slug TEXT NOT NULL,
  score NUMERIC(6, 5) NOT NULL DEFAULT 0.5 CHECK (score >= 0 AND score <= 1),
  attempts_count INTEGER NOT NULL DEFAULT 0,
  correct_count INTEGER NOT NULL DEFAULT 0,
  due_at TIMESTAMPTZ NULL,
  formula_version TEXT NOT NULL DEFAULT 'weighted_accuracy_v1',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, topic_slug)
);

ALTER TABLE public.topic_mastery ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users view own topic mastery" ON public.topic_mastery;
CREATE POLICY "Users view own topic mastery" ON public.topic_mastery
  FOR SELECT USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.question_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES public.practice_questions(id) ON DELETE RESTRICT,
  reason TEXT NOT NULL,
  details TEXT NULL,
  status TEXT NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.question_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users create own question reports" ON public.question_reports;
CREATE POLICY "Users create own question reports" ON public.question_reports
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users view own question reports" ON public.question_reports;
CREATE POLICY "Users view own question reports" ON public.question_reports
  FOR SELECT USING (auth.uid() = user_id);

COMMIT;
