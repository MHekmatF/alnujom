-- Phase 18 (spec/018-reports-moderation) — Migration 1/8
-- public.reports — a signed-in user's complaint about one approved listing.
--
-- Visibility: reporter-self OR reports.manage read (policies in Migration 3,
-- 20260530120003). NO publisher path, NO aggregate count, NO anonymous reader.
--
-- Write model:
--   - INSERT: only via public.submit_report(uuid,text,text) SECURITY DEFINER
--     RPC (Migration 6, 20260530120006). No direct client INSERT grant — so a
--     client cannot create a report that bypasses the auth + approved-listing
--     + dedup gates (FR-010).
--   - UPDATE/DELETE: none from clients; resolution/claim happen via the
--     privileged resolve_report_internal / start_report_review RPCs
--     (Migration 7, 20260530120007).
--
-- Keys / FKs (R-131):
--   - listing_id -> public.listings ON DELETE RESTRICT: listings soft-delete
--     via status='deleted', so RESTRICT never fires normally; it preserves the
--     report (and its My-Reports / banner rows) against accidental hard-delete.
--   - reporter_user_id -> auth.users ON DELETE CASCADE: deleting an account
--     removes its reports (user_preferences / favorites precedent).
--   - reviewing_by / resolved_by -> auth.users ON DELETE SET NULL: the report
--     survives the moderator's account deletion (audit attribution goes null).
--
-- Dedup (FR-004): the ux_reports_open_per_reporter_listing partial unique index
-- enforces at most one OPEN ('new'/'reviewing') report per (reporter, listing);
-- terminal ('resolved'/'dismissed') rows fall outside it, so a fresh report can
-- be filed after resolution. submit_report's EXISTS guard is the friendly
-- pre-check; this index is the race backstop.

CREATE TABLE IF NOT EXISTS public.reports (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id            UUID         NOT NULL REFERENCES public.listings(id)  ON DELETE RESTRICT,
  reporter_user_id      UUID         NOT NULL REFERENCES auth.users(id)       ON DELETE CASCADE,
  reason                TEXT         NOT NULL
                          CHECK (reason IN (
                            'fake_listing','wrong_price','already_sold_or_rented',
                            'duplicate','spam','wrong_location',
                            'inappropriate_content','other')),
  note                  TEXT         CHECK (note IS NULL OR char_length(note) <= 1000),
  status                TEXT         NOT NULL DEFAULT 'new'
                          CHECK (status IN ('new','reviewing','resolved','dismissed')),
  reviewing_by          UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewing_started_at  TIMESTAMPTZ,
  resolved_by           UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at           TIMESTAMPTZ,
  resolution            TEXT,
  metadata              JSONB,        -- optional reporter IP / user-agent (FR-010(e))
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Admin queue: newest-first by status.
CREATE INDEX IF NOT EXISTS idx_reports_status_created
  ON public.reports (status, created_at DESC);

-- My-Reports + per-listing reporter-banner lookup.
CREATE INDEX IF NOT EXISTS idx_reports_reporter_created
  ON public.reports (reporter_user_id, created_at DESC);

-- FK + sibling-resolve scan.
CREATE INDEX IF NOT EXISTS idx_reports_listing
  ON public.reports (listing_id);

-- Open-report dedup (FR-004): at most one OPEN report per (reporter, listing).
CREATE UNIQUE INDEX IF NOT EXISTS ux_reports_open_per_reporter_listing
  ON public.reports (reporter_user_id, listing_id)
  WHERE status IN ('new','reviewing');

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
