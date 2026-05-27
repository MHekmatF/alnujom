-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase C Migration 3/4
-- public.v_inquiries_inbox — publisher / sender / admin inbox view.
--
-- Contracts:
--   - contracts/phase16-v-inquiries-inbox-view.md
--   - data-model.md §2.7
--
-- This view JOINs `public.inquiries` to `public.listings` to surface the
-- listing title + status alongside the inquiry, and computes the decrypted
-- inquirer phone per row via the SECURITY DEFINER
-- `public.decrypt_inquirer_phone(uuid)` function (Sub-Phase D). That
-- function self-gates against the three-tier visibility rule and returns
-- NULL for unauthorized callers, so even if the row leaks through RLS
-- (it does not — the underlying inquiries table policies hide unauthorized
-- rows), the phone column would still mask.
--
-- RLS inheritance: the view uses the Postgres 15 default SECURITY INVOKER
-- semantics, so reads honor the underlying inquiries RLS policies
-- (publisher / sender / admin three-tier rule).
--
-- DEPENDENCY: This migration is FILES-ONLY at Sub-Phase C apply time. It
-- references `public.decrypt_inquirer_phone(uuid)` which is created by
-- Sub-Phase D's `20260527120006_create_decrypt_inquirer_phone_fn.sql`.
-- The merge cascade applies this migration only AFTER Phase 4 lands the
-- decrypt function. Filename ordering (120006 < 120007) means Supabase's
-- migration runner picks the correct order on a fresh project.

CREATE OR REPLACE VIEW public.v_inquiries_inbox AS
SELECT
  i.id,
  i.listing_id,
  l.title                             AS listing_title,
  l.status                            AS listing_status,
  i.sender_user_id,
  i.sender_name,
  i.message,
  i.status,
  i.created_at,
  i.updated_at,
  public.decrypt_inquirer_phone(i.id) AS inquirer_phone_decrypted
FROM public.inquiries i
JOIN public.listings  l ON l.id = i.listing_id;

GRANT SELECT ON public.v_inquiries_inbox TO authenticated;
-- NOT granted to anon.
