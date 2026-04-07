-- Repair remote enum drift for exam_type.
-- Safe to run on environments that already have the expected values.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'exam_type'
  ) THEN
    CREATE TYPE exam_type AS ENUM ('apprentice', 'journeyman', 'master');
  END IF;
END $$;

ALTER TYPE exam_type ADD VALUE IF NOT EXISTS 'apprentice';
ALTER TYPE exam_type ADD VALUE IF NOT EXISTS 'journeyman';
ALTER TYPE exam_type ADD VALUE IF NOT EXISTS 'master';
