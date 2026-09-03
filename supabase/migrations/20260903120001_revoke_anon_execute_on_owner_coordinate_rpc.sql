-- =============================================================================
-- Take EXECUTE on the owner/admin coordinate RPC away from `anon`
-- =============================================================================
-- `public.get_listing_coordinates(uuid)` returns a listing's EXACT latitude and
-- longitude to a caller who owns the listing or holds `listings.view_all`. It is
-- the counterpart to `listing_marker_coordinates()`, which is the public,
-- visibility-gated one.
--
-- The migration that created it (20260901120001) says in as many words:
--
--     authenticated ONLY — deliberately no anon grant (a guest has no listing
--     to own and no moderation permission, so it could only ever return NULL
--     for them).
--
-- It grants only `authenticated`. Yet the live database on 2026-09-03 answers
-- `has_function_privilege('anon', …, 'EXECUTE') = true`. The grant was never
-- written; it is Postgres's default **EXECUTE to PUBLIC** on a new function,
-- which `anon` inherits. Granting `authenticated` explicitly does not displace
-- it. This is the third time that default has quietly widened this schema — see
-- the note in 20260902120002 — and the only cure is to revoke it by name.
--
-- WHAT THIS IS, HONESTLY
--   Not a live leak. The function's own body resolves `auth.uid()` and checks
--   `current_user_has_permission('listings.view_all')`, so an anonymous caller
--   who reaches it gets NULL — the same NULL a missing listing returns. This
--   closes the gap between what the schema *says* and what it *grants*, removes
--   a standing entry from `get_advisors(security)`, and means the guard is no
--   longer the only thing standing between a guest and an exact coordinate.
--
-- CHECKED BEFORE WRITING THIS (2026-09-03, against production)
--   - No view in `public` references the function (0 rows).
--   - No RLS policy references it in `qual` or `with_check` (0 rows).
--   - Every caller in the app is an owner/admin path — the publisher edit form,
--     the revision snapshot, the admin listing review, the publisher dashboard
--     DTO — all of which run authenticated.
--   Revoking from `anon` therefore breaks no call site. Contrast
--   `current_user_has_permission`, which MUST keep its anon grant: an
--   anon-scoped RLS policy calls it, and revoking that one returns 42501 to
--   every guest. Do not "tidy up" the boolean helpers on the strength of this
--   file.
--
-- ROLLBACK
--   grant execute on function public.get_listing_coordinates(uuid) to anon;
--
-- VERIFY AFTER APPLYING
--   1. has_function_privilege('anon', 'public.get_listing_coordinates(uuid)',
--      'EXECUTE') is false, and the same for 'authenticated' is true.
--   2. Run supabase/scripts/probe_role_read_access.sql for both roles — still
--      zero failures.
--   3. On a device, signed in: open the publisher edit form on a listing with a
--      location, and the admin listing preview. Both read coordinates through
--      this RPC and must still show the pin.
-- =============================================================================

revoke execute on function public.get_listing_coordinates(uuid) from public;
revoke execute on function public.get_listing_coordinates(uuid) from anon;

-- Restate the grant the function is supposed to have, so the end state is
-- explicit rather than whatever the default left behind.
grant execute on function public.get_listing_coordinates(uuid) to authenticated;

comment on function public.get_listing_coordinates(uuid) is
  'SEC-I1: returns {"latitude":…,"longitude":…} for a listing the caller OWNS or '
  'can moderate (listings.view_all), else NULL — the same NULL a missing listing '
  'returns, so it discloses nothing about existence. EXECUTE is authenticated '
  'ONLY: the PUBLIC default was revoked in 20260903120001 because anon inherited '
  'it and no anon caller can ever get a non-NULL answer.';
