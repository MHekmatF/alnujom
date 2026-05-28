-- Phase 16 (spec/016-contact-inquiries) — Inbox-entry visibility gate.
--
-- FR-019 / Q6=B: the home inbox entry is visible to any user who owns ≥ 1
-- APPROVED listing — independent of whether they currently have unread
-- inquiries. (The unread badge is a separate signal via get_inbox_unread_count.)
--
-- Phase 7 T072 originally gated the entry on `unread_count > 0`, which hid the
-- entry whenever a publisher had zero new inquiries — a deviation from Q6=B.
-- This RPC restores the spec-faithful gate.
--
-- SECURITY DEFINER + STABLE; returns false for anonymous callers (auth.uid()
-- is null → EXISTS is false).

CREATE OR REPLACE FUNCTION public.publisher_owns_approved_listing()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.listings
     WHERE publisher_user_id = auth.uid()
       AND status = 'approved'
  );
$$;

GRANT EXECUTE ON FUNCTION public.publisher_owns_approved_listing() TO authenticated;
