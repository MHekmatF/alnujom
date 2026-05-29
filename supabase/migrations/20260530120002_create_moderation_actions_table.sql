-- Phase 18 (spec/018-reports-moderation) — Migration 2/8
-- public.moderation_actions — append-only record of an admin moderation action.
--
-- One row per resolved report (the triggering report plus any auto-resolved
-- siblings, FR-016). Written ONLY by resolve_report_internal (Migration 7,
-- 20260530120007); readable ONLY by reports.manage holders (policy in
-- Migration 3, 20260530120003). No client write path (REVOKE in Migration 3).
--
-- target_id is a PLAIN uuid column with NO FK (R-131): the audit log is
-- deliberately decoupled from the listing lifecycle, so the moderation trail
-- survives even if the target listing is later hard-deleted.
--
-- FKs:
--   - report_id -> public.reports ON DELETE SET NULL: the log entry survives
--     the report's deletion (e.g. reporter-account cascade).
--   - performed_by -> auth.users ON DELETE SET NULL: the log survives the
--     moderator's account deletion (attribution goes null, row stays).

CREATE TABLE IF NOT EXISTS public.moderation_actions (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type   TEXT         NOT NULL DEFAULT 'listing'
                  CHECK (target_type IN ('listing')),
  target_id     UUID         NOT NULL,
  report_id     UUID         REFERENCES public.reports(id) ON DELETE SET NULL,
  action        TEXT         NOT NULL
                  CHECK (action IN ('dismiss','hide','mark_duplicate','delete')),
  performed_by  UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  performed_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  reason        TEXT,
  before_state  JSONB,
  after_state   JSONB
);

CREATE INDEX IF NOT EXISTS idx_moderation_actions_target
  ON public.moderation_actions (target_type, target_id, performed_at DESC);

ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;
