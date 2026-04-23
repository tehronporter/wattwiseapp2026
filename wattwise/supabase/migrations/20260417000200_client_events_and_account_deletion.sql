BEGIN;

CREATE TABLE IF NOT EXISTS client_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'ios',
  user_id UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  exam_type exam_type NULL,
  jurisdiction_code TEXT NULL,
  device_id TEXT NULL,
  properties JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_client_events_event_name
  ON client_events(event_name);

CREATE INDEX IF NOT EXISTS idx_client_events_user_id
  ON client_events(user_id);

CREATE INDEX IF NOT EXISTS idx_client_events_occurred_at
  ON client_events(occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_client_events_platform
  ON client_events(platform);

ALTER TABLE client_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role manages client events" ON client_events;
CREATE POLICY "Service role manages client events" ON client_events
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

COMMIT;
