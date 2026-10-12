BEGIN;

CREATE TABLE IF NOT EXISTS public.content_sme_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_kind TEXT NOT NULL CHECK (content_kind IN ('lesson', 'practice_question', 'exam')),
  source_key TEXT NOT NULL,
  priority INTEGER NOT NULL CHECK (priority > 0),
  review_status TEXT NOT NULL DEFAULT 'not_started'
    CHECK (review_status IN ('not_started', 'in_review', 'changes_requested', 'approved')),
  required_artifacts JSONB NOT NULL DEFAULT '[]'::jsonb,
  assigned_reviewer_name TEXT NULL,
  reviewed_at TIMESTAMPTZ NULL,
  review_notes TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (content_kind, source_key),
  CHECK ((review_status <> 'approved') OR (assigned_reviewer_name IS NOT NULL AND reviewed_at IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_content_sme_reviews_release_queue
  ON public.content_sme_reviews (review_status, priority, content_kind);

ALTER TABLE public.content_sme_reviews ENABLE ROW LEVEL SECURITY;

-- No client policies: this is an editorial control record managed through a service-role
-- workflow until a dedicated reviewer console is introduced.

INSERT INTO public.content_sme_reviews (content_kind, source_key, priority, required_artifacts)
VALUES
  ('lesson', 'jr-les-005', 1, '["citation_check", "worked_example", "guided_code_lookup", "vetted_practice_set", "exam_blueprint_mapping", "second_reviewer_signoff"]'::jsonb),
  ('lesson', 'jr-les-009', 2, '["citation_check", "illustrated_concept_check", "guided_code_lookup", "vetted_practice_set", "exam_blueprint_mapping", "second_reviewer_signoff"]'::jsonb),
  ('lesson', 'jr-les-011', 3, '["citation_check", "worked_example", "guided_code_lookup", "vetted_practice_set", "exam_blueprint_mapping", "second_reviewer_signoff"]'::jsonb),
  ('lesson', 'jr-les-013', 4, '["citation_check", "worked_example", "guided_code_lookup", "vetted_practice_set", "exam_blueprint_mapping", "second_reviewer_signoff"]'::jsonb),
  ('lesson', 'jr-les-014', 5, '["citation_check", "worked_example", "guided_code_lookup", "vetted_practice_set", "exam_blueprint_mapping", "second_reviewer_signoff"]'::jsonb),
  ('lesson', 'jr-les-018', 6, '["citation_check", "worked_example", "guided_code_lookup", "vetted_practice_set", "exam_blueprint_mapping", "second_reviewer_signoff"]'::jsonb),
  ('lesson', 'jr-les-019', 7, '["citation_check", "worked_example", "guided_code_lookup", "vetted_practice_set", "exam_blueprint_mapping", "second_reviewer_signoff"]'::jsonb),
  ('lesson', 'jr-les-020', 8, '["citation_check", "worked_example", "guided_code_lookup", "vetted_practice_set", "exam_blueprint_mapping", "second_reviewer_signoff"]'::jsonb),
  ('lesson', 'jr-les-025', 9, '["citation_check", "worked_example", "guided_code_lookup", "vetted_practice_set", "exam_blueprint_mapping", "second_reviewer_signoff"]'::jsonb),
  ('lesson', 'jr-les-030', 10, '["citation_check", "worked_example", "guided_code_lookup", "vetted_practice_set", "exam_blueprint_mapping", "second_reviewer_signoff"]'::jsonb)
ON CONFLICT (content_kind, source_key) DO UPDATE
SET priority = EXCLUDED.priority,
    required_artifacts = EXCLUDED.required_artifacts,
    updated_at = now();

COMMIT;
