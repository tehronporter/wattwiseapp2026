-- Deterministic practice-question bank for quiz generation

CREATE TABLE IF NOT EXISTS practice_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_key TEXT NOT NULL UNIQUE,
  certification_level exam_type NOT NULL,
  topic_slug TEXT NOT NULL,
  topic_title TEXT NOT NULL,
  question_text TEXT NOT NULL,
  choices JSONB NOT NULL,
  correct_choice TEXT NOT NULL,
  explanation TEXT NOT NULL,
  nec_reference TEXT NULL,
  difficulty_level difficulty_level NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_practice_questions_certification_level
  ON practice_questions(certification_level);

CREATE INDEX IF NOT EXISTS idx_practice_questions_topic_slug
  ON practice_questions(topic_slug);

CREATE INDEX IF NOT EXISTS idx_practice_questions_is_active
  ON practice_questions(is_active);

CREATE TABLE IF NOT EXISTS quiz_question_assignments (
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  practice_question_id UUID NOT NULL REFERENCES practice_questions(id) ON DELETE CASCADE,
  question_number INTEGER NOT NULL,
  PRIMARY KEY (quiz_id, practice_question_id),
  UNIQUE (quiz_id, question_number)
);

CREATE INDEX IF NOT EXISTS idx_quiz_question_assignments_quiz_id
  ON quiz_question_assignments(quiz_id);

CREATE INDEX IF NOT EXISTS idx_quiz_question_assignments_practice_question_id
  ON quiz_question_assignments(practice_question_id);
