-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase D Migration 4/4
-- public.get_inbox_unread_count — cheap scalar read for the home AppBar badge.
--
-- Returns the count of inquiries whose listing the caller publishes AND whose
-- status is still 'new' (i.e., not yet acknowledged by the publisher).
--
-- SECURITY DEFINER + STABLE so view planners can inline / cache. Pure SQL body.
-- Authenticated-only — anonymous users have no inbox.

CREATE OR REPLACE FUNCTION public.get_inbox_unread_count()
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
STABLE
AS $$
  SELECT COUNT(*)::INTEGER
  FROM public.inquiries i
  JOIN public.listings  l ON l.id = i.listing_id
  WHERE l.publisher_user_id = auth.uid()
    AND i.status = 'new';
$$;

REVOKE ALL ON FUNCTION public.get_inbox_unread_count() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_inbox_unread_count() TO authenticated;
-- NOT granted to anon.
