-- Fully automated accuracy pipeline
-- Adds canonical verification metadata, normalized facts, claim linkage,
-- and publication gates for lessons and question-bank content.

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'content_publish_status'
  ) THEN
    CREATE TYPE content_publish_status AS ENUM ('draft', 'researched', 'auto_approved', 'published');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'content_freshness_status'
  ) THEN
    CREATE TYPE content_freshness_status AS ENUM ('fresh', 'stale', 'unknown', 'conflicted');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'content_claim_type'
  ) THEN
    CREATE TYPE content_claim_type AS ENUM (
      'nec_reference',
      'formula',
      'exam_strategy',
      'jurisdiction',
      'currentness',
      'definition',
      'other'
    );
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS verified_code_facts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fact_key TEXT NOT NULL UNIQUE,
  fact_type TEXT NOT NULL,
  jurisdiction_code TEXT NULL,
  exam_type exam_type NULL,
  code_cycle TEXT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  effective_date DATE NULL,
  expires_on DATE NULL,
  official_source_url TEXT NOT NULL,
  source_provider TEXT NOT NULL,
  source_priority INTEGER NOT NULL DEFAULT 100,
  source_hash TEXT NULL,
  source_retrieved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source_published_at TIMESTAMPTZ NULL,
  amendment_reference TEXT NULL,
  fact_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  freshness_status content_freshness_status NOT NULL DEFAULT 'unknown',
  staleness_reason TEXT NULL,
  conflict_group TEXT NULL,
  conflict_detected BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_verified_code_facts_fact_type
  ON verified_code_facts(fact_type);

CREATE INDEX IF NOT EXISTS idx_verified_code_facts_jurisdiction_code
  ON verified_code_facts(jurisdiction_code);

CREATE INDEX IF NOT EXISTS idx_verified_code_facts_freshness_status
  ON verified_code_facts(freshness_status);

CREATE INDEX IF NOT EXISTS idx_verified_code_facts_conflict_group
  ON verified_code_facts(conflict_group);

CREATE TABLE IF NOT EXISTS content_source_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_url TEXT NOT NULL UNIQUE,
  source_provider TEXT NOT NULL,
  source_kind TEXT NOT NULL,
  source_hash TEXT NULL,
  retrieved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at TIMESTAMPTZ NULL,
  title TEXT NULL,
  metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_content_source_documents_source_provider
  ON content_source_documents(source_provider);

ALTER TABLE lessons
  ADD COLUMN IF NOT EXISTS base_code_cycle TEXT NULL,
  ADD COLUMN IF NOT EXISTS jurisdiction_scope TEXT NOT NULL DEFAULT 'national',
  ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS source_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS source_hashes JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS verification_confidence NUMERIC(5, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS freshness_status content_freshness_status NOT NULL DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS publish_status content_publish_status NOT NULL DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS staleness_reason TEXT NULL,
  ADD COLUMN IF NOT EXISTS approval_notes TEXT NULL,
  ADD COLUMN IF NOT EXISTS needs_jurisdiction_overlay BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS disclaimer TEXT NULL;

ALTER TABLE lessons
  DROP CONSTRAINT IF EXISTS lessons_verification_confidence_range;

ALTER TABLE lessons
  ADD CONSTRAINT lessons_verification_confidence_range
  CHECK (verification_confidence >= 0 AND verification_confidence <= 100);

CREATE INDEX IF NOT EXISTS idx_lessons_publish_status
  ON lessons(publish_status);

CREATE INDEX IF NOT EXISTS idx_lessons_freshness_status
  ON lessons(freshness_status);

CREATE INDEX IF NOT EXISTS idx_lessons_last_verified_at
  ON lessons(last_verified_at);

ALTER TABLE practice_questions
  ADD COLUMN IF NOT EXISTS base_code_cycle TEXT NULL,
  ADD COLUMN IF NOT EXISTS jurisdiction_scope TEXT NOT NULL DEFAULT 'national',
  ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS source_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS source_hashes JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS verification_confidence NUMERIC(5, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS freshness_status content_freshness_status NOT NULL DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS publish_status content_publish_status NOT NULL DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS staleness_reason TEXT NULL,
  ADD COLUMN IF NOT EXISTS disclaimer TEXT NULL;

ALTER TABLE practice_questions
  DROP CONSTRAINT IF EXISTS practice_questions_verification_confidence_range;

ALTER TABLE practice_questions
  ADD CONSTRAINT practice_questions_verification_confidence_range
  CHECK (verification_confidence >= 0 AND verification_confidence <= 100);

CREATE INDEX IF NOT EXISTS idx_practice_questions_publish_status
  ON practice_questions(publish_status);

CREATE INDEX IF NOT EXISTS idx_practice_questions_freshness_status
  ON practice_questions(freshness_status);

CREATE TABLE IF NOT EXISTS lesson_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  claim_type content_claim_type NOT NULL,
  claim_text TEXT NOT NULL,
  claim_key TEXT NOT NULL,
  code_cycle TEXT NULL,
  jurisdiction_scope TEXT NOT NULL DEFAULT 'national',
  source_fact_ids UUID[] NOT NULL DEFAULT ARRAY[]::UUID[],
  conflict_detected BOOLEAN NOT NULL DEFAULT false,
  confidence NUMERIC(5, 2) NOT NULL DEFAULT 0,
  status content_publish_status NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lesson_id, claim_key)
);

ALTER TABLE lesson_claims
  DROP CONSTRAINT IF EXISTS lesson_claims_confidence_range;

ALTER TABLE lesson_claims
  ADD CONSTRAINT lesson_claims_confidence_range
  CHECK (confidence >= 0 AND confidence <= 100);

CREATE INDEX IF NOT EXISTS idx_lesson_claims_lesson_id
  ON lesson_claims(lesson_id);

CREATE INDEX IF NOT EXISTS idx_lesson_claims_claim_type
  ON lesson_claims(claim_type);

CREATE TABLE IF NOT EXISTS question_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  practice_question_id UUID NOT NULL REFERENCES practice_questions(id) ON DELETE CASCADE,
  claim_type content_claim_type NOT NULL,
  claim_text TEXT NOT NULL,
  claim_key TEXT NOT NULL,
  code_cycle TEXT NULL,
  jurisdiction_scope TEXT NOT NULL DEFAULT 'national',
  source_fact_ids UUID[] NOT NULL DEFAULT ARRAY[]::UUID[],
  conflict_detected BOOLEAN NOT NULL DEFAULT false,
  confidence NUMERIC(5, 2) NOT NULL DEFAULT 0,
  status content_publish_status NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (practice_question_id, claim_key)
);

ALTER TABLE question_claims
  DROP CONSTRAINT IF EXISTS question_claims_confidence_range;

ALTER TABLE question_claims
  ADD CONSTRAINT question_claims_confidence_range
  CHECK (confidence >= 0 AND confidence <= 100);

CREATE INDEX IF NOT EXISTS idx_question_claims_practice_question_id
  ON question_claims(practice_question_id);

CREATE TABLE IF NOT EXISTS lesson_fact_links (
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  fact_id UUID NOT NULL REFERENCES verified_code_facts(id) ON DELETE CASCADE,
  relationship TEXT NOT NULL DEFAULT 'supports',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (lesson_id, fact_id)
);

CREATE TABLE IF NOT EXISTS question_fact_links (
  practice_question_id UUID NOT NULL REFERENCES practice_questions(id) ON DELETE CASCADE,
  fact_id UUID NOT NULL REFERENCES verified_code_facts(id) ON DELETE CASCADE,
  relationship TEXT NOT NULL DEFAULT 'supports',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (practice_question_id, fact_id)
);

ALTER TABLE verified_code_facts DISABLE ROW LEVEL SECURITY;
ALTER TABLE content_source_documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_claims DISABLE ROW LEVEL SECURITY;
ALTER TABLE question_claims DISABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_fact_links DISABLE ROW LEVEL SECURITY;
ALTER TABLE question_fact_links DISABLE ROW LEVEL SECURITY;

COMMIT;
