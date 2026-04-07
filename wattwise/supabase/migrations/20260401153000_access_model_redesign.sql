ALTER TYPE subscription_tier RENAME VALUE 'free' TO 'preview';
ALTER TYPE subscription_tier RENAME VALUE 'pro' TO 'full_prep';
ALTER TYPE subscription_tier ADD VALUE IF NOT EXISTS 'fast_track';

ALTER TABLE subscriptions
  ADD COLUMN IF NOT EXISTS store_product_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS store_transaction_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS store_original_transaction_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS idx_subscriptions_store_product_id
  ON subscriptions(store_product_id);

ALTER TABLE purchase_receipts
  ADD COLUMN IF NOT EXISTS transaction_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS original_transaction_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS idx_purchase_receipts_transaction_id
  ON purchase_receipts(transaction_id);
