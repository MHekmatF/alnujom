-- Phase 19 (spec/019-agencies) — Migration 1/13
-- Creates: agency_status enum, public.agencies table, idx_agencies_status,
--          set_updated_at trigger (Phase 4 helper), RLS enable (policies in …005).
-- A brokerage owned by exactly one approved publisher. Public read only when
-- status='approved'; owner/active-member read at any status; agencies.view read
-- all. Writes via create_agency RPC + moderate_agency_internal only.
-- Idempotent: re-applying this migration leaves the schema unchanged.
-- References: data-model.md §1.1; research.md R-138 (one agency per owner),
--             R-144 (FK delete behaviors); contracts/phase19-agencies-table.md.

-- ───────────────────────────────────────────────────────────────────────────
-- 1. Enum: agency_status (NOT in init_enums.sql; distinct from
--    account_approval_status which lacks 'suspended')
-- ───────────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE agency_status AS ENUM ('pending','approved','rejected','suspended');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Table: public.agencies
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.agencies (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id   UUID          NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT          NOT NULL CHECK (length(trim(name)) > 0),
  description     TEXT,
  phone           TEXT,
  whatsapp        TEXT,
  address         TEXT,
  logo_path       TEXT,
  cover_path      TEXT,
  status          agency_status NOT NULL DEFAULT 'pending',
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Public directory + admin queue scans.
CREATE INDEX IF NOT EXISTS idx_agencies_status ON public.agencies (status);

-- ───────────────────────────────────────────────────────────────────────────
-- 3. set_updated_at trigger (reuses Phase 4 helper, as account_approval_requests)
-- ───────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_agencies_set_updated_at ON public.agencies;
CREATE TRIGGER trg_agencies_set_updated_at
  BEFORE UPDATE ON public.agencies
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ───────────────────────────────────────────────────────────────────────────
-- 4. RLS enable (policies attach in 20260531120005_create_agency_policies.sql)
-- ───────────────────────────────────────────────────────────────────────────
ALTER TABLE public.agencies ENABLE ROW LEVEL SECURITY;
