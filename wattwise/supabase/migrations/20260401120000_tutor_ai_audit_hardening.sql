-- Tutor / AI observability and persistence hardening

ALTER TABLE tutor_sessions
  ADD COLUMN IF NOT EXISTS title TEXT NULL,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS context_lesson_id UUID NULL REFERENCES lessons(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS context_quiz_attempt_id UUID NULL REFERENCES quiz_attempts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS context_nec_entry_id UUID NULL REFERENCES nec_entries(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_tutor_sessions_last_message_at
  ON tutor_sessions(last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_tutor_sessions_user_last_message
  ON tutor_sessions(user_id, last_message_at DESC);

ALTER TABLE tutor_messages
  ADD COLUMN IF NOT EXISTS message_text TEXT NULL,
  ADD COLUMN IF NOT EXISTS structured_json JSONB NULL,
  ADD COLUMN IF NOT EXISTS model_name TEXT NULL;

UPDATE tutor_messages
SET message_text = COALESCE(message_text, content)
WHERE message_text IS NULL;

ALTER TABLE tutor_messages
  ALTER COLUMN message_text SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tutor_messages_session_created
  ON tutor_messages(session_id, created_at);

ALTER TABLE ai_request_logs
  ADD COLUMN IF NOT EXISTS related_session_id UUID NULL REFERENCES tutor_sessions(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS related_nec_entry_id UUID NULL REFERENCES nec_entries(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS provider_name TEXT NULL,
  ADD COLUMN IF NOT EXISTS model_name TEXT NULL,
  ADD COLUMN IF NOT EXISTS input_tokens INTEGER NULL,
  ADD COLUMN IF NOT EXISTS output_tokens INTEGER NULL,
  ADD COLUMN IF NOT EXISTS prompt_version TEXT NULL,
  ADD COLUMN IF NOT EXISTS context_type TEXT NULL,
  ADD COLUMN IF NOT EXISTS error_code TEXT NULL;

CREATE INDEX IF NOT EXISTS idx_ai_request_logs_related_session
  ON ai_request_logs(related_session_id);

CREATE INDEX IF NOT EXISTS idx_ai_request_logs_related_nec
  ON ai_request_logs(related_nec_entry_id);

ALTER TABLE tutor_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_request_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own tutor messages" ON tutor_messages;
CREATE POLICY "Users can view own tutor messages" ON tutor_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM tutor_sessions
      WHERE tutor_sessions.id = tutor_messages.session_id
        AND tutor_sessions.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can view own ai usage counters" ON ai_usage_counters;
CREATE POLICY "Users can view own ai usage counters" ON ai_usage_counters
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own ai request logs" ON ai_request_logs;
CREATE POLICY "Users can view own ai request logs" ON ai_request_logs
  FOR SELECT USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS update_tutor_sessions_updated_at ON tutor_sessions;
CREATE TRIGGER update_tutor_sessions_updated_at
  BEFORE UPDATE ON tutor_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
