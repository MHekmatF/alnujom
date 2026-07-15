-- Phase 035 (DC Listing & Viewing) — publisher "withdraw edits".
--
-- Adds a 'withdrawn' terminal status + an owner-gated withdraw RPC so a
-- publisher can cancel their own open (draft|pending_review) stay-live edit from
-- the revision-status screen. Mirrors submit_listing_revision (owner check) and
-- reject_listing_revision (audit log). The live listing is left untouched; a
-- 'withdrawn' revision is excluded by find_open_revision's
-- status IN ('draft','pending_review') filter, so the "edit in review" badge
-- clears and the owner may start a fresh edit.
--
-- Applied to the live project via Supabase MCP apply_migration on 2026-07-15.

-- 1. Widen the status CHECK (additive; never breaks existing rows).
ALTER TABLE public.listing_revisions
  DROP CONSTRAINT IF EXISTS listing_revisions_status_check;
ALTER TABLE public.listing_revisions
  ADD CONSTRAINT listing_revisions_status_check
  CHECK (status = ANY (ARRAY['draft','pending_review','approved','rejected','withdrawn']));

-- 2. Owner-gated withdraw RPC.
CREATE OR REPLACE FUNCTION public.withdraw_listing_revision(p_revision_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $function$
DECLARE v_rev public.listing_revisions%ROWTYPE;
BEGIN
  SELECT lr.* INTO v_rev FROM public.listing_revisions AS lr
    WHERE lr.id = p_revision_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'revision not found'; END IF;
  IF v_rev.publisher_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'not the owner'; END IF;
  IF v_rev.status NOT IN ('draft', 'pending_review') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'revision cannot be withdrawn in its current status'; END IF;
  UPDATE public.listing_revisions AS lr
    SET status = 'withdrawn' WHERE lr.id = p_revision_id;
  INSERT INTO public.audit_logs
    (actor_user_id, action, target_type, target_id, before_state, after_state)
  VALUES (auth.uid(), 'listing_revision.withdrawn', 'listing_revisions',
    p_revision_id::text, to_jsonb(v_rev), jsonb_build_object('status', 'withdrawn'));
END; $function$;

-- 3. Only signed-in owners may call it (anon default EXECUTE is revoked).
REVOKE ALL ON FUNCTION public.withdraw_listing_revision(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.withdraw_listing_revision(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.withdraw_listing_revision(uuid) TO authenticated;
