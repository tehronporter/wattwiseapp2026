-- Content collection completion schema upgrades
-- Adds storage for practice exam blueprints, jurisdiction profiles, and state exam metadata.

-- Ensure District of Columbia exists in jurisdictions.
INSERT INTO jurisdictions (code, name, country_code, sort_order)
VALUES ('DC', 'District of Columbia', 'US', 51)
ON CONFLICT (code) DO NOTHING;

-- Full-length practice exam blueprints (content pack mirrors this model).
CREATE TABLE IF NOT EXISTS practice_exam_blueprints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blueprint_key TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  certification_level exam_type NOT NULL,
  exam_provider TEXT NULL,
  license_type TEXT NULL,
  jurisdiction_code TEXT NULL REFERENCES jurisdictions(code),
  code_cycle TEXT NULL,
  question_count INTEGER NOT NULL,
  time_limit_minutes INTEGER NOT NULL,
  passing_score INTEGER NULL,
  structure_notes TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_practice_exam_blueprints_level
  ON practice_exam_blueprints(certification_level);

CREATE INDEX IF NOT EXISTS idx_practice_exam_blueprints_jurisdiction
  ON practice_exam_blueprints(jurisdiction_code);

-- Ordered question membership for each blueprint.
-- We key to practice_questions.source_key because content pack IDs map cleanly to source_key values.
CREATE TABLE IF NOT EXISTS practice_exam_questions (
  practice_exam_blueprint_id UUID NOT NULL REFERENCES practice_exam_blueprints(id) ON DELETE CASCADE,
  question_source_key TEXT NOT NULL REFERENCES practice_questions(source_key) ON DELETE RESTRICT,
  question_number INTEGER NOT NULL,
  expected_answer TEXT NULL,
  PRIMARY KEY (practice_exam_blueprint_id, question_source_key),
  UNIQUE (practice_exam_blueprint_id, question_number)
);

CREATE INDEX IF NOT EXISTS idx_practice_exam_questions_blueprint
  ON practice_exam_questions(practice_exam_blueprint_id);

CREATE INDEX IF NOT EXISTS idx_practice_exam_questions_source_key
  ON practice_exam_questions(question_source_key);

-- Jurisdiction-level exam profile card metadata.
CREATE TABLE IF NOT EXISTS jurisdiction_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  jurisdiction_code TEXT NOT NULL UNIQUE REFERENCES jurisdictions(code) ON DELETE CASCADE,
  state_name TEXT NOT NULL,
  exam_provider TEXT NOT NULL,
  licensing_authority TEXT NOT NULL,
  adopted_nec_cycle TEXT NOT NULL,
  exam_question_count INTEGER NOT NULL,
  exam_time_limit_minutes INTEGER NOT NULL,
  passing_score INTEGER NOT NULL,
  open_book BOOLEAN NOT NULL DEFAULT FALSE,
  references_allowed TEXT NULL,
  reciprocity_notes TEXT NULL,
  last_verified_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_jurisdiction_profiles_provider
  ON jurisdiction_profiles(exam_provider);

CREATE INDEX IF NOT EXISTS idx_jurisdiction_profiles_cycle
  ON jurisdiction_profiles(adopted_nec_cycle);

-- License naming map by jurisdiction + certification level.
CREATE TABLE IF NOT EXISTS license_type_maps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  jurisdiction_profile_id UUID NOT NULL REFERENCES jurisdiction_profiles(id) ON DELETE CASCADE,
  certification_level exam_type NOT NULL,
  license_name TEXT NOT NULL,
  UNIQUE (jurisdiction_profile_id, certification_level)
);

CREATE INDEX IF NOT EXISTS idx_license_type_maps_profile
  ON license_type_maps(jurisdiction_profile_id);

-- Source links and bulletins used to verify jurisdiction profiles.
CREATE TABLE IF NOT EXISTS state_exam_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  jurisdiction_profile_id UUID NOT NULL REFERENCES jurisdiction_profiles(id) ON DELETE CASCADE,
  source_url TEXT NOT NULL,
  source_type TEXT NOT NULL DEFAULT 'official',
  accessed_on DATE NULL,
  notes TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_state_exam_sources_profile
  ON state_exam_sources(jurisdiction_profile_id);

-- State overlay tagging for question-bank records.
CREATE TABLE IF NOT EXISTS state_question_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_source_key TEXT NOT NULL REFERENCES practice_questions(source_key) ON DELETE CASCADE,
  jurisdiction_code TEXT NOT NULL REFERENCES jurisdictions(code) ON DELETE CASCADE,
  question_type TEXT NOT NULL,
  exam_provider TEXT NULL,
  license_type TEXT NULL,
  code_cycle TEXT NULL,
  source_url TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (question_source_key, jurisdiction_code, question_type)
);

CREATE INDEX IF NOT EXISTS idx_state_question_tags_state
  ON state_question_tags(jurisdiction_code);

CREATE INDEX IF NOT EXISTS idx_state_question_tags_question
  ON state_question_tags(question_source_key);
