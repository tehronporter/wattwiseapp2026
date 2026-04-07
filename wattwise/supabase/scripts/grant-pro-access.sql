-- Manual Pro Access Grant Script
-- Use this to grant pro/unlimited access to a specific email address
--
-- HOW TO USE:
-- 1. Replace 'hello@tehron.xyz' with the target email address
-- 2. Run this query in the Supabase SQL editor (Tables > SQL Editor)
-- 3. The user must have signed up at least once first
--
-- Result: User will have full_prep tier with unlimited access (no expiry)
-- Limits returned by sync_subscription:
--   - preview_quizzes_limit: -1 (unlimited)
--   - tutor_messages_limit: -1 (unlimited)
--   - nec_explanations_limit: -1 (unlimited)

-- Step 1: Find the user
SELECT id, email FROM auth.users WHERE email = 'hello@tehron.xyz';

-- Step 2: Grant pro access (replace user_id with the result from Step 1)
-- Option A: If subscription doesn't exist yet
INSERT INTO subscriptions (user_id, tier, status, expires_at)
SELECT id, 'full_prep', 'active', NULL
FROM auth.users
WHERE email = 'hello@tehron.xyz'
ON CONFLICT (user_id) DO NOTHING;

-- Option B: If subscription already exists, update it
UPDATE subscriptions
SET
  tier = 'full_prep',
  status = 'active',
  expires_at = NULL,
  updated_at = now()
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'hello@tehron.xyz');

-- Step 3: Verify the change
SELECT
  au.email,
  s.tier,
  s.status,
  s.expires_at,
  s.created_at,
  s.updated_at
FROM subscriptions s
JOIN auth.users au ON s.user_id = au.id
WHERE au.email = 'hello@tehron.xyz';

-- Expected Result:
-- email               | tier      | status | expires_at | created_at | updated_at
-- hello@tehron.xyz    | full_prep | active | NULL       | [date]     | [date]
