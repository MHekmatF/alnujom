-- Migration 4: Create Audit Logs + reusable log_audit() trigger function
-- Phase 4 — Supabase Foundation (specs/004-supabase-foundation)
-- See: spec.md, plan.md, research.md
-- Apply via: Supabase MCP apply_migration(name='20260506120004_create_audit_logs', query='<file body>')

-- (a) audit_logs table
CREATE TABLE IF NOT EXISTS audit_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action          TEXT NOT NULL,
  target_type     TEXT NOT NULL,
  target_id       TEXT,
  before_state    JSONB,
  after_state     JSONB,
  ip              INET,
  user_agent      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- (b) log_audit() reusable trigger function
CREATE OR REPLACE FUNCTION log_audit() RETURNS TRIGGER
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

  INSERT INTO audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
    VALUES (auth.uid(), v_action, TG_TABLE_NAME, v_target_id, v_before, v_after);

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- (b1) Revoke EXECUTE from REST-exposed roles — log_audit() is trigger-only.
-- Without this, anon and authenticated could invoke /rest/v1/rpc/log_audit.
-- Triggers fire as the trigger's owner regardless of EXECUTE grants on roles,
-- so this revoke does not affect trg_profiles_audit_status or any later
-- log_audit-using trigger.
REVOKE EXECUTE ON FUNCTION log_audit() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION log_audit() FROM anon, authenticated;

-- (c) Phase 4 concrete trigger on profiles status changes
DROP TRIGGER IF EXISTS trg_profiles_audit_status ON profiles;
CREATE TRIGGER trg_profiles_audit_status
  AFTER UPDATE OF account_status, publisher_status ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION log_audit('profile.status_changed', 'account_status,publisher_status', 'user_id');
