-- Phase 22 (spec/022-notifications-realtime) — Migration 4/11.
-- Re-based CREATE-OR-REPLACE amendment (R-183) of the Phase 5 account-decision RPCs
-- approve_account_approval_request / reject_account_approval_request (base 20260510120001).
-- Additive ONLY: every existing line preserved verbatim (signature, search_path=public,
-- admin gate, guarded UPDATEs, NOT FOUND raises); inserts exactly ONE
-- PERFORM public.enqueue_notification(...) on the success/transition branch after the
-- profiles.account_status write. NO reason text in params (FR-004). Grants unchanged.
-- Idempotent: create-or-replace; safely re-runnable.

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

  -- Phase 22 fan-out: exactly one notification on the approval transition (FR-001/FR-003).
  PERFORM public.enqueue_notification(p_user_id, 'account_approved', '{}'::jsonb);
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

  -- Phase 22 fan-out: NO reason text in params — full reason stays in-app only (FR-004).
  PERFORM public.enqueue_notification(p_user_id, 'account_rejected', '{}'::jsonb);
END;
$$;
