-- 20260717120005_add_user_facing_fk_indexes
--
-- QA E2E fix — PERF-L4 (P3): add covering indexes for 3 user-facing foreign keys that
-- are filtered/joined on hot read paths but had no leading index:
--   * reviews.listing_id   — listing-detail reviews list
--   * viewings.listing_id  — listing viewings
--   * listings.agency_id   — agency's listings + the v_listings_public agency join
-- Pure additive; safe. (The broader 19-unindexed-FK set from the perf audit is left for
-- a dedicated pass — these 3 are the user-facing ones.)
create index if not exists reviews_listing_id_idx  on public.reviews  using btree (listing_id);
create index if not exists viewings_listing_id_idx on public.viewings using btree (listing_id);
create index if not exists listings_agency_id_idx  on public.listings using btree (agency_id);
