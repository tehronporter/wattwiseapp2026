-- WattWise Database Schema
-- Complete production schema for electrician exam prep app

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE exam_type AS ENUM ('apprentice', 'journeyman', 'master');
CREATE TYPE lesson_status AS ENUM ('not_started', 'in_progress', 'completed');
CREATE TYPE quiz_type AS ENUM ('quick_quiz', 'full_practice_exam', 'weak_area_review');
CREATE TYPE difficulty_level AS ENUM ('beginner', 'intermediate', 'advanced');
CREATE TYPE subscription_tier AS ENUM ('free', 'pro');
CREATE TYPE tutor_context_type AS ENUM ('general', 'lesson', 'quiz_review', 'nec_detail');
CREATE TYPE ai_request_type AS ENUM ('tutor', 'quiz_generation', 'nec_explanation', 'recommendation', 'other');

-- ============================================================================
-- DOMAIN 1: Identity & User Preferences
-- ============================================================================

CREATE TABLE IF NOT EXISTS jurisdictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  country_code TEXT NOT NULL DEFAULT 'US',
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_jurisdictions_code ON jurisdictions(code);
CREATE INDEX idx_jurisdictions_is_active ON jurisdictions(is_active);
CREATE INDEX idx_jurisdictions_sort_order ON jurisdictions(sort_order);

-- Seed jurisdictions (US states)
INSERT INTO jurisdictions (code, name, country_code, sort_order) VALUES
  ('AL', 'Alabama', 'US', 1), ('AK', 'Alaska', 'US', 2), ('AZ', 'Arizona', 'US', 3),
  ('AR', 'Arkansas', 'US', 4), ('CA', 'California', 'US', 5), ('CO', 'Colorado', 'US', 6),
  ('CT', 'Connecticut', 'US', 7), ('DE', 'Delaware', 'US', 8), ('FL', 'Florida', 'US', 9),
  ('GA', 'Georgia', 'US', 10), ('HI', 'Hawaii', 'US', 11), ('ID', 'Idaho', 'US', 12),
  ('IL', 'Illinois', 'US', 13), ('IN', 'Indiana', 'US', 14), ('IA', 'Iowa', 'US', 15),
  ('KS', 'Kansas', 'US', 16), ('KY', 'Kentucky', 'US', 17), ('LA', 'Louisiana', 'US', 18),
  ('ME', 'Maine', 'US', 19), ('MD', 'Maryland', 'US', 20), ('MA', 'Massachusetts', 'US', 21),
  ('MI', 'Michigan', 'US', 22), ('MN', 'Minnesota', 'US', 23), ('MS', 'Mississippi', 'US', 24),
  ('MO', 'Missouri', 'US', 25), ('MT', 'Montana', 'US', 26), ('NE', 'Nebraska', 'US', 27),
  ('NV', 'Nevada', 'US', 28), ('NH', 'New Hampshire', 'US', 29), ('NJ', 'New Jersey', 'US', 30),
  ('NM', 'New Mexico', 'US', 31), ('NY', 'New York', 'US', 32), ('NC', 'North Carolina', 'US', 33),
  ('ND', 'North Dakota', 'US', 34), ('OH', 'Ohio', 'US', 35), ('OK', 'Oklahoma', 'US', 36),
  ('OR', 'Oregon', 'US', 37), ('PA', 'Pennsylvania', 'US', 38), ('RI', 'Rhode Island', 'US', 39),
  ('SC', 'South Carolina', 'US', 40), ('SD', 'South Dakota', 'US', 41), ('TN', 'Tennessee', 'US', 42),
  ('TX', 'Texas', 'US', 43), ('UT', 'Utah', 'US', 44), ('VT', 'Vermont', 'US', 45),
  ('VA', 'Virginia', 'US', 46), ('WA', 'Washington', 'US', 47), ('WV', 'West Virginia', 'US', 48),
  ('WI', 'Wisconsin', 'US', 49), ('WY', 'Wyoming', 'US', 50)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NULL,
  display_name TEXT NULL,
  exam_type exam_type NULL,
  jurisdiction_id UUID NULL REFERENCES jurisdictions(id),
  daily_study_goal_minutes INTEGER NOT NULL DEFAULT 30,
  onboarding_completed BOOLEAN NOT NULL DEFAULT false,
  subscription_tier subscription_tier NOT NULL DEFAULT 'free',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_active_at TIMESTAMPTZ NULL
);

CREATE INDEX idx_profiles_jurisdiction_id ON profiles(jurisdiction_id);
CREATE INDEX idx_profiles_exam_type ON profiles(exam_type);
CREATE INDEX idx_profiles_subscription_tier ON profiles(subscription_tier);
CREATE INDEX idx_profiles_onboarding_completed ON profiles(onboarding_completed);

CREATE TABLE IF NOT EXISTS study_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  preferred_study_mode TEXT NULL,
  preferred_quiz_length INTEGER NULL,
  wants_daily_reminders BOOLEAN NOT NULL DEFAULT false,
  preferred_reminder_time TIME NULL,
  language_code TEXT NOT NULL DEFAULT 'en',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_study_preferences_user_id ON study_preferences(user_id);

-- ============================================================================
-- DOMAIN 2: Content & Curriculum
-- ============================================================================

CREATE TABLE IF NOT EXISTS modules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT NULL,
  exam_type exam_type NULL,
  difficulty_level difficulty_level NULL,
  sort_order INTEGER NOT NULL,
  is_published BOOLEAN NOT NULL DEFAULT true,
  estimated_minutes INTEGER NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_modules_slug ON modules(slug);
CREATE INDEX idx_modules_sort_order ON modules(sort_order);
CREATE INDEX idx_modules_exam_type ON modules(exam_type);
CREATE INDEX idx_modules_is_published ON modules(is_published);

CREATE TABLE IF NOT EXISTS module_jurisdictions (
  module_id UUID NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
  jurisdiction_id UUID NOT NULL REFERENCES jurisdictions(id) ON DELETE CASCADE,
  PRIMARY KEY (module_id, jurisdiction_id)
);

CREATE INDEX idx_module_jurisdictions_jurisdiction_id ON module_jurisdictions(jurisdiction_id);

CREATE TABLE IF NOT EXISTS lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id UUID NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  subtitle TEXT NULL,
  summary TEXT NULL,
  exam_type exam_type NULL,
  difficulty_level difficulty_level NULL,
  sort_order INTEGER NOT NULL,
  estimated_minutes INTEGER NULL,
  is_published BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_lessons_slug ON lessons(slug);
CREATE INDEX idx_lessons_module_id ON lessons(module_id);
CREATE INDEX idx_lessons_sort_order ON lessons(sort_order);
CREATE INDEX idx_lessons_module_sort ON lessons(module_id, sort_order);
CREATE INDEX idx_lessons_is_published ON lessons(is_published);

CREATE TABLE IF NOT EXISTS lesson_sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  sort_order INTEGER NOT NULL,
  section_type TEXT NOT NULL,
  heading TEXT NULL,
  body_markdown TEXT NULL,
  body_plaintext TEXT NULL,
  meta_json JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_lesson_sections_lesson_id ON lesson_sections(lesson_id);
CREATE INDEX idx_lesson_sections_lesson_sort ON lesson_sections(lesson_id, sort_order);

CREATE TABLE IF NOT EXISTS topic_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_topic_tags_slug ON topic_tags(slug);

CREATE TABLE IF NOT EXISTS lesson_topic_tags (
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  topic_tag_id UUID NOT NULL REFERENCES topic_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (lesson_id, topic_tag_id)
);

CREATE INDEX idx_lesson_topic_tags_topic_id ON lesson_topic_tags(topic_tag_id);

CREATE TABLE IF NOT EXISTS module_topic_tags (
  module_id UUID NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
  topic_tag_id UUID NOT NULL REFERENCES topic_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (module_id, topic_tag_id)
);

-- ============================================================================
-- DOMAIN 3: NEC (National Electrical Code)
-- ============================================================================

CREATE TABLE IF NOT EXISTS nec_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_code TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  canonical_text_excerpt TEXT NULL,
  simplified_summary TEXT NOT NULL,
  edition TEXT NULL,
  topic_notes TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_nec_entries_reference_code ON nec_entries(reference_code);
CREATE INDEX idx_nec_entries_is_active ON nec_entries(is_active);

CREATE TABLE IF NOT EXISTS nec_entry_topic_tags (
  nec_entry_id UUID NOT NULL REFERENCES nec_entries(id) ON DELETE CASCADE,
  topic_tag_id UUID NOT NULL REFERENCES topic_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (nec_entry_id, topic_tag_id)
);

CREATE TABLE IF NOT EXISTS lesson_nec_references (
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  nec_entry_id UUID NOT NULL REFERENCES nec_entries(id) ON DELETE CASCADE,
  display_order INTEGER NOT NULL DEFAULT 0,
  context_note TEXT NULL,
  PRIMARY KEY (lesson_id, nec_entry_id)
);

CREATE INDEX idx_lesson_nec_references_nec_id ON lesson_nec_references(nec_entry_id);

CREATE TABLE IF NOT EXISTS nec_search_index (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nec_entry_id UUID NOT NULL REFERENCES nec_entries(id) ON DELETE CASCADE UNIQUE,
  search_text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- DOMAIN 4: Progress & Study Activity
-- ============================================================================

CREATE TABLE IF NOT EXISTS lesson_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  status lesson_status NOT NULL DEFAULT 'not_started',
  completion_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0,
  started_at TIMESTAMPTZ NULL,
  completed_at TIMESTAMPTZ NULL,
  study_minutes_spent INTEGER NOT NULL DEFAULT 0,
  last_accessed_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, lesson_id)
);

CREATE INDEX idx_lesson_progress_user_id ON lesson_progress(user_id);
CREATE INDEX idx_lesson_progress_lesson_id ON lesson_progress(lesson_id);
CREATE INDEX idx_lesson_progress_status ON lesson_progress(status);

CREATE TABLE IF NOT EXISTS study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  session_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  session_end TIMESTAMPTZ NULL,
  total_minutes INTEGER NOT NULL DEFAULT 0,
  activity_type TEXT NOT NULL,
  context_json JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_study_sessions_user_id ON study_sessions(user_id);
CREATE INDEX idx_study_sessions_session_start ON study_sessions(session_start);

CREATE TABLE IF NOT EXISTS daily_study_goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  goal_date DATE NOT NULL,
  target_minutes INTEGER NOT NULL,
  minutes_completed INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, goal_date)
);

CREATE INDEX idx_daily_study_goals_user_id ON daily_study_goals(user_id);
CREATE INDEX idx_daily_study_goals_goal_date ON daily_study_goals(goal_date);

-- ============================================================================
-- DOMAIN 5: Quiz & Assessment
-- ============================================================================

CREATE TABLE IF NOT EXISTS quizzes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_type quiz_type NOT NULL,
  question_count INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quiz_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_text TEXT NOT NULL,
  choices JSONB NOT NULL,
  correct_choice TEXT NOT NULL,
  explanation TEXT NOT NULL,
  difficulty_level difficulty_level NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quiz_question_topics (
  quiz_question_id UUID NOT NULL REFERENCES quiz_questions(id) ON DELETE CASCADE,
  topic_tag_id UUID NOT NULL REFERENCES topic_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (quiz_question_id, topic_tag_id)
);

CREATE TABLE IF NOT EXISTS quiz_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ NULL,
  answers JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_quiz_attempts_user_id ON quiz_attempts(user_id);
CREATE INDEX idx_quiz_attempts_quiz_id ON quiz_attempts(quiz_id);

CREATE TABLE IF NOT EXISTS quiz_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_attempt_id UUID NOT NULL REFERENCES quiz_attempts(id) ON DELETE CASCADE UNIQUE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  score NUMERIC(5, 2) NOT NULL,
  correct_count INTEGER NOT NULL,
  total_count INTEGER NOT NULL,
  results_json JSONB NOT NULL DEFAULT '{}',
  weak_topics TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_quiz_results_user_id ON quiz_results(user_id);
CREATE INDEX idx_quiz_results_created_at ON quiz_results(created_at);

CREATE TABLE IF NOT EXISTS weak_topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  topic_tag_id UUID NOT NULL REFERENCES topic_tags(id) ON DELETE CASCADE,
  failure_count INTEGER NOT NULL DEFAULT 1,
  last_failed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, topic_tag_id)
);

CREATE INDEX idx_weak_topics_user_id ON weak_topics(user_id);
CREATE INDEX idx_weak_topics_topic_id ON weak_topics(topic_tag_id);

-- ============================================================================
-- DOMAIN 6: Tutor & AI Interaction
-- ============================================================================

CREATE TABLE IF NOT EXISTS tutor_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  context_type tutor_context_type NOT NULL,
  context_id UUID NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ NULL,
  message_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tutor_sessions_user_id ON tutor_sessions(user_id);
CREATE INDEX idx_tutor_sessions_context_type ON tutor_sessions(context_type);

CREATE TABLE IF NOT EXISTS tutor_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES tutor_sessions(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  meta_json JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tutor_messages_session_id ON tutor_messages(session_id);

CREATE TABLE IF NOT EXISTS ai_request_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  request_type ai_request_type NOT NULL,
  prompt_tokens INTEGER NULL,
  completion_tokens INTEGER NULL,
  total_tokens INTEGER NULL,
  model_used TEXT NULL,
  status TEXT NOT NULL,
  error_message TEXT NULL,
  response_time_ms INTEGER NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ai_request_logs_user_id ON ai_request_logs(user_id);
CREATE INDEX idx_ai_request_logs_request_type ON ai_request_logs(request_type);
CREATE INDEX idx_ai_request_logs_created_at ON ai_request_logs(created_at);

-- ============================================================================
-- DOMAIN 7: Subscription & Entitlements
-- ============================================================================

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  tier subscription_tier NOT NULL DEFAULT 'free',
  status TEXT NOT NULL DEFAULT 'active',
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NULL,
  cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_tier ON subscriptions(tier);
CREATE INDEX idx_subscriptions_expires_at ON subscriptions(expires_at);

CREATE TABLE IF NOT EXISTS ai_usage_counters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  counter_date DATE NOT NULL,
  tutor_messages_used INTEGER NOT NULL DEFAULT 0,
  tutor_messages_limit INTEGER NOT NULL DEFAULT 5,
  nec_explanations_used INTEGER NOT NULL DEFAULT 0,
  nec_explanations_limit INTEGER NOT NULL DEFAULT 3,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, counter_date)
);

CREATE INDEX idx_ai_usage_counters_user_id ON ai_usage_counters(user_id);

CREATE TABLE IF NOT EXISTS purchase_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  receipt_data TEXT NOT NULL,
  platform TEXT NOT NULL,
  verified_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_purchase_receipts_user_id ON purchase_receipts(user_id);

-- ============================================================================
-- DOMAIN 8: Analytics & Operational Logging
-- ============================================================================

CREATE TABLE IF NOT EXISTS app_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NULL REFERENCES profiles(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  event_data JSONB NOT NULL DEFAULT '{}',
  platform TEXT NOT NULL,
  app_version TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_app_events_user_id ON app_events(user_id);
CREATE INDEX idx_app_events_event_type ON app_events(event_type);
CREATE INDEX idx_app_events_created_at ON app_events(created_at);

CREATE TABLE IF NOT EXISTS feature_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  feature_name TEXT NOT NULL,
  usage_count INTEGER NOT NULL DEFAULT 1,
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, feature_name)
);

CREATE INDEX idx_feature_usage_user_id ON feature_usage(user_id);
CREATE INDEX idx_feature_usage_feature_name ON feature_usage(feature_name);

-- ============================================================================
-- ROW-LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_study_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE weak_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE tutor_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_usage_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_usage ENABLE ROW LEVEL SECURITY;

-- Policies: Users can only see their own data
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view own study preferences" ON study_preferences
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view own lesson progress" ON lesson_progress
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view own quiz results" ON quiz_results
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view own tutor sessions" ON tutor_sessions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view own subscription" ON subscriptions
  FOR SELECT USING (auth.uid() = user_id);

-- Public read access for content (no RLS, read-only)
ALTER TABLE modules DISABLE ROW LEVEL SECURITY;
ALTER TABLE lessons DISABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_sections DISABLE ROW LEVEL SECURITY;
ALTER TABLE topic_tags DISABLE ROW LEVEL SECURITY;
ALTER TABLE nec_entries DISABLE ROW LEVEL SECURITY;
ALTER TABLE jurisdictions DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- TRIGGERS (auto-update updated_at timestamps)
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_study_preferences_updated_at BEFORE UPDATE ON study_preferences
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lesson_progress_updated_at BEFORE UPDATE ON lesson_progress
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_modules_updated_at BEFORE UPDATE ON modules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lessons_updated_at BEFORE UPDATE ON lessons
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lesson_sections_updated_at BEFORE UPDATE ON lesson_sections
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_nec_entries_updated_at BEFORE UPDATE ON nec_entries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_quiz_results_updated_at BEFORE UPDATE ON quiz_results
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_weak_topics_updated_at BEFORE UPDATE ON weak_topics
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ai_usage_counters_updated_at BEFORE UPDATE ON ai_usage_counters
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_feature_usage_updated_at BEFORE UPDATE ON feature_usage
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
