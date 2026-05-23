-- Migration: Phase 12 — FR-024 Trigger + log_audit() amendment for session-variable handoff
-- Spec: specs/012-listing-approval (Phase 12 — Listing Approval Workflow)
-- Source of truth: specs/012-listing-approval/data-model.md §1.1 — §1.4
-- Contract: specs/012-listing-approval/contracts/phase12-trigger-and-log-audit-amendment.md
-- Implements: FR-024 (mandatory amendment)
-- Research: R-43 (session-variable handoff design), R-49 (function name audit),
--           R-44 (Q4=A JSON storage rep), R-05 narrow relaxation, R-57 (SECURITY DEFINER safety)
-- Clarification: Q7=A — Edge Function service-role callers hand off admin UID + JSON-encoded
--                rejection reason to Phase 10/4 triggers via Postgres session variables
--                (set_config('app.current_user_id', ...) + set_config('app.current_rejection_reason', ...)),
--                amended trigger bodies COALESCE the session-var source against auth.uid() so that:
--                  - Edge Function callers (service-role client, no auth.uid()) attribute correctly
--                  - All Phase 5–11 direct-JWT callers continue to attribute via auth.uid() fallback
--                  - Phase 10 listing_status_history.reason is populated by reject_listing only
--
-- Phase 4's supabase/migrations/20260506120004_create_audit_logs.sql remains UNEDITED.
-- Phase 10's supabase/migrations/20260519120006_create_listing_status_history.sql remains UNEDITED.
-- All 3 amendments live exclusively in this Phase 12 migration (R-35 immutability preserved).

-- =============================================================================
-- 1. NEW: Session-variable setter functions (data-model.md §1.1, R-43, R-57)
-- =============================================================================

-- Setter for the admin's UID. Called by the approve_listing AND reject_listing
-- Edge Functions immediately BEFORE the privileged UPDATE so the amended
-- trigger functions can source `changed_by` AND `actor_user_id` via the
-- session variable instead of the service-role client's auth.uid() (which is NULL).
--
-- The session variable is scoped to the current transaction (third arg `true`),
-- so it leaks neither to subsequent requests nor to other concurrent transactions.
-- SECURITY DEFINER + SET search_path = public, pg_temp per R-57 safety analysis.
CREATE OR REPLACE FUNCTION public.set_app_user_id_for_session(user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM set_config('app.current_user_id', user_id::text, true);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_app_user_id_for_session(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_app_user_id_for_session(UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_app_user_id_for_session(UUID) TO service_role;
-- NOTE: Intentionally NOT granted to authenticated or anon. The only caller is
-- the Edge Function's service-role-bound client.

-- Setter for the rejection-reason JSON-encoded TEXT payload (Q4=A storage rep,
-- data-model.md §1.2, R-44).
-- Called by the reject_listing Edge Function immediately BEFORE the UPDATE so
-- the amended status-transition trigger can source the `reason` column from
-- the session variable instead of the hardcoded NULL from Phase 10's original
-- trigger body.
CREATE OR REPLACE FUNCTION public.set_app_rejection_reason_for_session(reason_json TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM set_config('app.current_rejection_reason', reason_json, true);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_app_rejection_reason_for_session(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_app_rejection_reason_for_session(TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_app_rejection_reason_for_session(TEXT) TO service_role;

-- =============================================================================
-- 2. AMENDED: public.listing_status_transition_trigger_fn()
--    (data-model.md §1.3, R-43 + R-49)
-- =============================================================================
-- Phase 10 original body sourced from
--   supabase/migrations/20260519120006_create_listing_status_history.sql lines 32-46.
-- Phase 12 amendment vs Phase 10:
--   - `changed_by` source: auth.uid()
--     -> coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid())
--   - `reason` source: hardcoded NULL
--     -> nullif(current_setting('app.current_rejection_reason', true), '')
-- All other lines byte-identical to Phase 10.
CREATE OR REPLACE FUNCTION public.listing_status_transition_trigger_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.listing_status_history (listing_id, previous_status, new_status, changed_by, reason)
    VALUES (
      NEW.id,
      NULL,
      NEW.status,
      coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
      nullif(current_setting('app.current_rejection_reason', true), '')
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.listing_status_history (listing_id, previous_status, new_status, changed_by, reason)
    VALUES (
      NEW.id,
      OLD.status,
      NEW.status,
      coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
      nullif(current_setting('app.current_rejection_reason', true), '')
    );
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;
-- NOTE: CREATE OR REPLACE rebinds the function body; the existing trigger
-- `listing_status_transition_trigger` on public.listings continues to fire
-- (no DROP/CREATE TRIGGER required).

-- =============================================================================
-- 3. AMENDED: public.listings_audit_trigger_fn()
--    (data-model.md §1.3 — listings_audit, R-49)
-- =============================================================================
-- Phase 10 original body sourced from
--   supabase/migrations/20260519120006_create_listing_status_history.sql lines 53-90.
-- Phase 12 amendment vs Phase 10:
--   - Every `auth.uid()` inside INSERT INTO public.audit_logs (...) VALUES (...)
--     replaced with coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid())
-- All six action keys (listing.created, listing.updated, listing.submitted, listing.approved,
-- listing.rejected, listing.paused, listing.expired, listing.sold, listing.rented, listing.deleted)
-- and their JSONB shapes preserved verbatim.
CREATE OR REPLACE FUNCTION public.listings_audit_trigger_fn()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
  status_verb TEXT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
    VALUES (
      coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
      'listing.created', 'listings', NEW.id::text, NULL, to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
    VALUES (
      coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
      'listing.updated', 'listings', NEW.id::text, to_jsonb(OLD), to_jsonb(NEW)
    );
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      status_verb := CASE NEW.status
        WHEN 'pending_review' THEN 'listing.submitted'
        WHEN 'approved'       THEN 'listing.approved'
        WHEN 'rejected'       THEN 'listing.rejected'
        WHEN 'paused'         THEN 'listing.paused'
        WHEN 'expired'        THEN 'listing.expired'
        WHEN 'sold'           THEN 'listing.sold'
        WHEN 'rented'         THEN 'listing.rented'
        WHEN 'deleted'        THEN 'listing.deleted'
        ELSE NULL
      END;
      IF status_verb IS NOT NULL THEN
        INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
        VALUES (
          coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
          status_verb, 'listings', NEW.id::text, to_jsonb(OLD), to_jsonb(NEW)
        );
      END IF;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
    VALUES (
      coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
      'listing.deleted', 'listings', OLD.id::text, to_jsonb(OLD), NULL
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;
-- NOTE: CREATE OR REPLACE rebinds the function body; the existing trigger
-- `listings_audit_trigger` on public.listings continues to fire.

-- =============================================================================
-- 4. AMENDED: public.log_audit()
--    (data-model.md §1.4, R-05 narrow relaxation)
-- =============================================================================
-- Phase 4 original body sourced from
--   supabase/migrations/20260506120004_create_audit_logs.sql lines 21-80.
-- Phase 12 amendment vs Phase 4 — SINGLE LINE CHANGE only:
--   - line 76 of original: VALUES (auth.uid(), v_action, TG_TABLE_NAME, v_target_id, v_before, v_after);
--   - Phase 12:            VALUES (coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
--                                  v_action, TG_TABLE_NAME, v_target_id, v_before, v_after);
-- Every other line byte-identical to Phase 4. R-05 narrow relaxation only.
-- Phase 5–11 callers (account_approvals, user_roles, roles, role_permissions,
-- permissions, governorates/cities/areas, currencies/exchange_rates, listing_media)
-- continue to attribute correctly via the auth.uid() fallback (session var unset).
CREATE OR REPLACE FUNCTION public.log_audit() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_action      TEXT := TG_ARGV[0];
  v_columns     TEXT := COALESCE(TG_ARGV[1], '');
  v_pk_col      TEXT := COALESCE(TG_ARGV[2], 'id');
  v_before      JSONB := 'null'::jsonb;
  v_after       JSONB := 'null'::jsonb;
  v_target_id   TEXT;
  v_col_array   TEXT[];
  v_changed     BOOLEAN := FALSE;
  v_col         TEXT;
BEGIN
  -- Resolve target_id from PK column name (works for any PK name).
  IF TG_OP = 'DELETE' THEN
    v_target_id := to_jsonb(OLD) ->> v_pk_col;
  ELSE
    v_target_id := to_jsonb(NEW) ->> v_pk_col;
  END IF;

  -- Build before/after JSONB filtered to the configured column list.
  IF v_columns = '*' OR v_columns = '' THEN
    IF TG_OP <> 'INSERT' THEN v_before := to_jsonb(OLD); END IF;
    IF TG_OP <> 'DELETE' THEN v_after  := to_jsonb(NEW); END IF;
  ELSE
    v_col_array := string_to_array(v_columns, ',');
    IF TG_OP <> 'INSERT' THEN
      v_before := '{}'::jsonb;
      FOREACH v_col IN ARRAY v_col_array LOOP
        v_before := v_before || jsonb_build_object(v_col, to_jsonb(OLD) -> v_col);
      END LOOP;
    END IF;
    IF TG_OP <> 'DELETE' THEN
      v_after := '{}'::jsonb;
      FOREACH v_col IN ARRAY v_col_array LOOP
        v_after := v_after || jsonb_build_object(v_col, to_jsonb(NEW) -> v_col);
      END LOOP;
    END IF;
  END IF;

  -- Audit-noise filter: for UPDATE with a column list, skip the INSERT
  -- if NONE of the listed columns actually changed.
  IF TG_OP = 'UPDATE' AND v_columns <> '*' AND v_columns <> '' THEN
    FOREACH v_col IN ARRAY v_col_array LOOP
      IF (to_jsonb(OLD) -> v_col) IS DISTINCT FROM (to_jsonb(NEW) -> v_col) THEN
        v_changed := TRUE;
        EXIT;
      END IF;
    END LOOP;
    IF NOT v_changed THEN
      RETURN COALESCE(NEW, OLD);
    END IF;
  END IF;

  -- Phase 12 amendment: COALESCE actor source against session variable (R-05 narrow relaxation).
  INSERT INTO audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
    VALUES (
      coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
      v_action, TG_TABLE_NAME, v_target_id, v_before, v_after
    );

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Re-apply Phase 4's role revokes (CREATE OR REPLACE preserves grants, but be defensive).
REVOKE EXECUTE ON FUNCTION log_audit() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION log_audit() FROM anon, authenticated;
