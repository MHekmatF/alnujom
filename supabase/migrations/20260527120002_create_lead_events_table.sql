-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase B Migration 2/3
-- public.lead_events — lightweight engagement-signal stream feeding future
-- analytics (Phase 19 agency analytics, Phase 20 admin dashboard).
--
-- Constraints:
--   - Q4=C: ON DELETE RESTRICT on listing_id (consistent with public.inquiries).
--   - Q5=B: metadata column carries {ip, user_agent} populated by the
--     submit_inquiry / record_lead_event RPCs (Sub-Phase D). Publishers
--     never see metadata — only admins via v_lead_events_admin (FR-014b).
--   - 'favorite_added' event_type is reserved for Phase 17; no Phase 16
--     write path emits it.
--
-- RLS posture:
--   - This migration enables RLS on the table.
--   - Policies land in Sub-Phase C (`20260527120004_create_lead_events_policies.sql`).
--   - All client writes go through `record_lead_event` / `submit_inquiry`
--     SECURITY DEFINER RPCs; direct INSERT/UPDATE/DELETE is revoked in
--     Sub-Phase C / D.

CREATE TABLE IF NOT EXISTS public.lead_events (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id      UUID         NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT,
  user_id         UUID         NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type      TEXT         NOT NULL
                    CHECK (event_type IN ('phone_revealed','whatsapp_clicked','inquiry_sent','favorite_added')),
  metadata        JSONB        NULL,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE public.lead_events ENABLE ROW LEVEL SECURITY;

-- Per-listing chronological reads (publisher analytics, admin oversight).
CREATE INDEX IF NOT EXISTS idx_lead_events_listing_created
  ON public.lead_events (listing_id, created_at DESC);

-- Per-event-type analytics aggregates (counts of phone_revealed vs
-- whatsapp_clicked vs inquiry_sent per listing).
CREATE INDEX IF NOT EXISTS idx_lead_events_listing_type
  ON public.lead_events (listing_id, event_type, created_at DESC);
