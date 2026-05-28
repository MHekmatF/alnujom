-- Phase 16 (spec/016-contact-inquiries) — admin oversight read-only support.
--
-- Adds a computed `viewer_is_publisher` boolean to v_inquiries_inbox so the
-- detail page can render read-only for admins (and senders) viewing an inquiry
-- on a listing they do NOT publish. Per the admin-oversight contract, Phase 16
-- ships no admin-side status-mutation UX: only the listing's publisher may
-- mutate status (RLS inquiries_update_publisher enforces this at the data
-- layer; this column lets the UI hide the affordance + skip the auto new→seen).
--
-- Privacy: we expose a boolean (am-I-the-publisher), NOT the raw
-- publisher_user_id. Evaluated with auth.uid() under the view's existing
-- security_invoker = true (set in 20260527120014), so it reflects the caller.

CREATE OR REPLACE VIEW public.v_inquiries_inbox
WITH (security_invoker = true) AS
SELECT
  i.id,
  i.listing_id,
  l.title                              AS listing_title,
  l.status                             AS listing_status,
  i.sender_user_id,
  i.sender_name,
  i.message,
  i.status,
  i.created_at,
  i.updated_at,
  public.decrypt_inquirer_phone(i.id)  AS inquirer_phone_decrypted,
  (l.publisher_user_id = auth.uid())   AS viewer_is_publisher
FROM public.inquiries i
JOIN public.listings  l ON l.id = i.listing_id;

REVOKE ALL ON public.v_inquiries_inbox FROM PUBLIC, anon;
GRANT SELECT ON public.v_inquiries_inbox TO authenticated;
