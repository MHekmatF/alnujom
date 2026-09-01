-- 20260717120001_revoke_client_writes_on_public_views
--
-- QA E2E fix — SEC-H1 (CRITICAL) + SEC-M1 + the write-half of SEC-M2.
--
-- Finding: 11 public views granted INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER
-- to anon and/or authenticated. On a single-base-table auto-updatable SECURITY
-- DEFINER view (v_agencies is the proven case) a client write runs as the view
-- OWNER and BYPASSES the base table's RLS — an anonymous/authenticated caller could
-- self-create a pre-`approved` agency or tamper with existing rows, skipping the
-- approval workflow entirely. The same latent write path existed on 10 more views.
--
-- Safe by construction: the app never writes THROUGH a view — every write goes
-- through an RPC or an RLS-gated base table (verified across the whole client).
-- Only client write privileges are revoked here; SELECT is untouched, so all reads
-- (home / search / map / favorites / ads / reports / publisher screens) keep working.
-- Server-side triggers and Edge Functions run as table owner and are unaffected.
revoke insert, update, delete, truncate, references, trigger
  on public.v_ads_serving,
     public.v_agencies,
     public.v_favorites,
     public.v_inquiries_inbox,
     public.v_lead_events_admin,
     public.v_lead_events_publisher,
     public.v_listings_map_public,
     public.v_listings_public,
     public.v_publisher_listings,
     public.v_publisher_ratings,
     public.v_reports
  from anon, authenticated;
