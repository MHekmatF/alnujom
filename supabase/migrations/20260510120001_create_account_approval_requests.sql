-- Phase 5 (spec/005-auth-profile) — Migration 1/5
-- Creates: account_approval_status enum, account_approval_requests table,
--          auto_create_account_approval_request() trigger fn + trigger on profiles,
--          approve_account_approval_request / reject_account_approval_request RPCs,
--          RLS + policies (bundled from supabase/policies/account_approval_requests_policies.sql per Phase 4 R-02).
-- Idempotent: re-applying this migration leaves the schema unchanged.
-- References: research.md R-04 (table shape), R-05 (audit trigger reuse — separate migration), R-14 (RPCs).

-- ───────────────────────────────────────────────────────────────────────────
-- 1. Enum: account_approval_status (narrower than profiles.account_status — see R-04)
-- ───────────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE account_approval_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Table: account_approval_requests
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS account_approval_requests (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  status           account_approval_status NOT NULL DEFAULT 'pending',
  rejection_reason TEXT NULL,
  reviewed_by      UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at      TIMESTAMPTZ NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT account_approval_requests_rejection_reason_when_rejected CHECK (
    (status = 'rejected' AND rejection_reason IS NOT NULL AND length(trim(rejection_reason)) > 0)
    OR (status <> 'rejected' AND rejection_reason IS NULL)
  ),
  CONSTRAINT account_approval_requests_reviewed_when_decided CHECK (
    (status IN ('approved', 'rejected') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (status = 'pending' AND reviewed_by IS NULL AND reviewed_at IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_account_approval_requests_status_pending
  ON account_approval_requests (created_at DESC)
  WHERE status = 'pending';

COMMENT ON TABLE account_approval_requests IS
  'Phase 5: one row per user tracking the first-review outcome of admin approval. '
  'Auto-populated on profiles insert. Lifecycle: pending → approved | rejected (terminal in v1). '
  'Suspended/un-suspend/reopen-rejection are deferred to Phase 7 super-admin UI.';

-- ───────────────────────────────────────────────────────────────────────────
-- 3. set_updated_at trigger (reuses Phase 4 helper)
-- ───────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_account_approval_requests_set_updated_at ON account_approval_requests;
CREATE TRIGGER trg_account_approval_requests_set_updated_at
  BEFORE UPDATE ON account_approval_requests
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- ───────────────────────────────────────────────────────────────────────────
-- 4. Auto-population trigger on profiles insert
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auto_create_account_approval_request()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  INSERT INTO account_approval_requests (user_id, status)
  VALUES (NEW.user_id, 'pending')
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_auto_create_account_approval_request ON profiles;
CREATE TRIGGER trg_profiles_auto_create_account_approval_request
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_account_approval_request();

-- ───────────────────────────────────────────────────────────────────────────
-- 5. RPCs: approve / reject (atomic, admin-gated; per research R-14)
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION approve_account_approval_request(p_user_id UUID)
  RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  IF NOT current_user_is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  UPDATE account_approval_requests
  SET status = 'approved',
      rejection_reason = NULL,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      updated_at = now()
  WHERE user_id = p_user_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'no pending request for user_id %', p_user_id USING ERRCODE = '02000';
  END IF;

  -- Profile UPDATE is guarded by account_status='pending' so out-of-band changes are not silently overwritten.
  UPDATE profiles
  SET account_status = 'approved',
      updated_at = now()
  WHERE user_id = p_user_id AND account_status = 'pending';
END;
$$;

CREATE OR REPLACE FUNCTION reject_account_approval_request(p_user_id UUID, p_reason TEXT)
  RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  IF NOT current_user_is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'rejection_reason required' USING ERRCODE = '22023';
  END IF;

  UPDATE account_approval_requests
  SET status = 'rejected',
      rejection_reason = p_reason,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      updated_at = now()
  WHERE user_id = p_user_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'no pending request for user_id %', p_user_id USING ERRCODE = '02000';
  END IF;

  UPDATE profiles
  SET account_status = 'rejected',
      updated_at = now()
  WHERE user_id = p_user_id AND account_status = 'pending';
END;
$$;

-- ───────────────────────────────────────────────────────────────────────────
-- 6. RLS + policies (generated from supabase/policies/account_approval_requests_policies.sql)
-- ───────────────────────────────────────────────────────────────────────────
ALTER TABLE account_approval_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS account_approval_requests_self_read ON account_approval_requests;
CREATE POLICY account_approval_requests_self_read
  ON account_approval_requests
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS account_approval_requests_admin_read ON account_approval_requests;
CREATE POLICY account_approval_requests_admin_read
  ON account_approval_requests
  FOR SELECT
  TO authenticated
  USING (current_user_is_admin());

DROP POLICY IF EXISTS account_approval_requests_admin_update ON account_approval_requests;
CREATE POLICY account_approval_requests_admin_update
  ON account_approval_requests
  FOR UPDATE
  TO authenticated
  USING (current_user_is_admin())
  WITH CHECK (current_user_is_admin());

-- No INSERT policy: trigger-only.
-- No DELETE policy: cascade-only.
