-- Phase 15 audit fix: v_listings_map_public was created as a SECURITY DEFINER
-- view (Postgres 15+ default when WITH clause omitted), which bypassed RLS on
-- public.listings. The Sub-Phase C migration body has been updated to include
-- WITH (security_invoker = true); this ALTER applies the same change to the
-- already-deployed view without rewriting the body.
--
-- Restores the "defense in depth via inherited RLS" posture documented in
-- specs/015-map-view/data-model.md §6. Matches Phase 10's v_publisher_listings
-- pattern. Clears Supabase advisor 0010_security_definer_view (level ERROR).
ALTER VIEW public.v_listings_map_public SET (security_invoker = true);
