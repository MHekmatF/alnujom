-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase B Migration 1/3
-- public.inquiries — publisher-targeted written contact submissions.
--
-- Constraints:
--   - ADR-0001: inquirer_phone_encrypted holds Supabase Vault ciphertext.
--     Plaintext NEVER lands in this column. Writes only via the
--     `submit_inquiry` SECURITY DEFINER RPC (Sub-Phase D).
--   - Q4=C: ON DELETE RESTRICT on listing_id. Listings use soft-delete via
--     status='deleted', so the FK does not regress when a listing is removed.
--   - Q7=B: message capped at 2000 chars; sender_name capped at 100 chars.
--   - FR-013, FR-021a: status enum + transition trigger (Sub-Phase B Migration 3/3).
--   - FR-015: three indexes covering the inbox queries.
--
-- RLS posture:
--   - This migration enables RLS on the table.
--   - Policies land in Sub-Phase C (`20260527120003_create_inquiries_policies.sql`).
--   - INSERT/UPDATE/DELETE direct writes are revoked in Sub-Phase C / D so that
--     every write path goes through a SECURITY DEFINER RPC.

CREATE TABLE IF NOT EXISTS public.inquiries (
  id                          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id                  UUID         NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT,
  sender_user_id              UUID         NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  sender_name                 TEXT         NOT NULL CHECK (length(trim(sender_name)) BETWEEN 1 AND 100),
  inquirer_phone_encrypted    BYTEA        NULL,
  inquirer_phone_key_name     TEXT         NOT NULL DEFAULT 'app-inquirer-phone-key',
  message                     TEXT         NOT NULL CHECK (length(trim(message)) BETWEEN 1 AND 2000),
  status                      TEXT         NOT NULL DEFAULT 'new'
                                CHECK (status IN ('new','seen','responded','closed','spam')),
  created_at                  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;

-- updated_at maintenance (uses the project-wide helper from
-- 20260506120002_create_profiles.sql).
DROP TRIGGER IF EXISTS trg_inquiries_set_updated_at ON public.inquiries;
CREATE TRIGGER trg_inquiries_set_updated_at
  BEFORE UPDATE ON public.inquiries
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Per-listing chronological reads (publisher inbox, per-listing drill-down).
CREATE INDEX IF NOT EXISTS idx_inquiries_listing_created
  ON public.inquiries (listing_id, created_at DESC);

-- Active-funnel partial index — backs get_inbox_unread_count and the inbox
-- status-filtered reads.
CREATE INDEX IF NOT EXISTS idx_inquiries_listing_status
  ON public.inquiries (listing_id, status, created_at DESC)
  WHERE status IN ('new','seen','responded');

-- Signed-in inquirer self-read path.
CREATE INDEX IF NOT EXISTS idx_inquiries_sender
  ON public.inquiries (sender_user_id)
  WHERE sender_user_id IS NOT NULL;
