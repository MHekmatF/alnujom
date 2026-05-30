-- Phase 19 (spec/019-agencies) — Migration 3/13
-- Creates: public.agency_verification_requests (account-approval-template CHECKs),
--          ux_agency_open_verification partial unique, idx_agency_verification_decision,
--          set_updated_at trigger (Phase 4 helper), RLS enable (policies in …005).
-- Structurally mirrors the Phase 5 account_approval_requests (20260510120001).
-- The ID-document + commercial-registration numbers are NOT columns here — they
-- go to Vault (migration …007). One OPEN request per agency
-- (ux_agency_open_verification). decision pending→approved/rejected.
-- Idempotent: re-applying this migration leaves the schema unchanged.
-- References: data-model.md §1.3; ADR-0001 (Vault PII);
--             contracts/phase19-agency-verification-requests-table.md.

-- ───────────────────────────────────────────────────────────────────────────
-- 1. Table: public.agency_verification_requests
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.agency_verification_requests (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id        UUID        NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE,
  decision         TEXT        NOT NULL DEFAULT 'pending'
                     CHECK (decision IN ('pending','approved','rejected')),
  decision_reason  TEXT,
  evidence_urls    JSONB,                 -- storage paths in agency-documents bucket
  submitted_by     UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  submitted_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_by      UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at      TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT agency_verification_reason_when_rejected CHECK (
    (decision = 'rejected' AND decision_reason IS NOT NULL AND length(trim(decision_reason)) > 0)
    OR (decision <> 'rejected' AND decision_reason IS NULL)
  ),
  CONSTRAINT agency_verification_reviewed_when_decided CHECK (
    (decision IN ('approved','rejected') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (decision = 'pending' AND reviewed_by IS NULL AND reviewed_at IS NULL)
  )
);

-- One OPEN (pending) verification request per agency; a fresh request may follow a rejection.
CREATE UNIQUE INDEX IF NOT EXISTS ux_agency_open_verification
  ON public.agency_verification_requests (agency_id) WHERE decision = 'pending';

CREATE INDEX IF NOT EXISTS idx_agency_verification_decision
  ON public.agency_verification_requests (decision, submitted_at DESC);

-- ───────────────────────────────────────────────────────────────────────────
-- 2. set_updated_at trigger (reuses Phase 4 helper)
-- ───────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_agency_verification_set_updated_at ON public.agency_verification_requests;
CREATE TRIGGER trg_agency_verification_set_updated_at
  BEFORE UPDATE ON public.agency_verification_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ───────────────────────────────────────────────────────────────────────────
-- 3. RLS enable (policies attach in 20260531120005_create_agency_policies.sql)
-- ───────────────────────────────────────────────────────────────────────────
ALTER TABLE public.agency_verification_requests ENABLE ROW LEVEL SECURITY;
