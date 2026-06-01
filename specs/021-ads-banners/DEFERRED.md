# Deferred work — Phase 21 (Ads & Banners)

Intentional gaps left out of the Phase 21 PR. Each is non-blocking for the MVP
acceptance criteria (SC-001..SC-013); recorded here per the project convention
(memory `project_deferred_work`). Surfaced by the Wave 2 Opus UI review.

## D-1 — `search`-kind ad link does not pre-fill the search query
- **What**: An ad with `link_kind = 'search'` carries a free-text query in
  `link_value` (R-179). On tap, `AdSlot._openTarget` pushes the search route but
  does NOT pass the query text, because `SearchPage` currently accepts only a
  `PropertyType?` as its router `extra`, not a free-text string.
- **Current behaviour**: navigates to `/search` with the search bar focused
  (graceful, non-crashing — satisfies FR-018). The ad's intended query is lost.
- **To complete**: extend `SearchPage`'s router contract to accept an optional
  free-text query (e.g. a typed `extra` record or a query param) and have
  `AdSlot` pass `link_value` through. Touches `app_router.dart` + `SearchPage`
  + `ad_slot.dart`. File: `lib/features/ads/presentation/widgets/ad_slot.dart`
  (the `AdLinkKind.search` branch).

## D-2 — `home_middle_banner` position drifts with pagination
- **What**: R-176 intends the middle banner as a single slot "after the first
  feed page/batch". The current insertion places `AdSlot(home_middle_banner)`
  after the entire listings `SliverList`, so as pagination appends more pages
  the banner's on-screen position drifts downward (it stays below the growing
  list, above the footer).
- **Current behaviour**: it IS a single, non-repeated slot (the important part
  of R-176) — only its absolute position is not pinned to "end of page 1".
  Acceptable for v1.
- **To complete**: split the home feed so the middle banner is injected at a
  fixed index (end of the first page) rather than after the whole list. File:
  `lib/features/home/presentation/pages/home_page.dart`.
