-- Grant pro/unlimited access to hello@tehron.xyz
-- This migration ensures the user gets full_prep tier with unlimited access
-- NOTE: The user must be signed up first for this to work

-- Function to safely grant pro access by email
CREATE OR REPLACE FUNCTION grant_pro_access_by_email(user_email TEXT)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  tier subscription_tier,
  status TEXT,
  expires_at TIMESTAMPTZ
) AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Find the user by email
  SELECT id INTO v_user_id FROM auth.users WHERE email = user_email LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found. User must sign up first.', user_email;
  END IF;

  -- Update or create subscription with full_prep tier and no expiry
  INSERT INTO subscriptions (user_id, tier, status, expires_at)
  VALUES (v_user_id, 'full_prep', 'active', NULL)
  ON CONFLICT (user_id)
  DO UPDATE SET
    tier = 'full_prep',
    status = 'active',
    expires_at = NULL,
    updated_at = now();

  RETURN QUERY
  SELECT
    s.user_id,
    au.email,
    s.tier,
    s.status,
    s.expires_at
  FROM subscriptions s
  JOIN auth.users au ON s.user_id = au.id
  WHERE au.email = user_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant pro access to hello@tehron.xyz
-- This will fail gracefully if the user doesn't exist yet
-- Run this after the user signs up for the first time
DO $$
DECLARE
  result_row RECORD;
BEGIN
  FOR result_row IN
    SELECT * FROM grant_pro_access_by_email('hello@tehron.xyz')
  LOOP
    RAISE NOTICE 'Granted pro access to % (user_id: %)', result_row.email, result_row.user_id;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not grant pro access: %', SQLERRM;
END $$;
