# Phase 10 Deferred Work

Captured: 2026-05-19

## Resolved During Implementation

- "Save and exit" navigation: Resolved. `ListingFormBloc._onSaveStepAndExit` now emits `savedAndExited: true`; the page listener navigates to `AppRoutes.shellHome` on the flag transition. Originally the button saved data but kept the user on the form.
- Price-step `priceAmount` before `priceCurrencyCode` race: Resolved. `step_prices.dart` now auto-syncs the dropdown's visible default currency into BLoC state on first FutureBuilder resolution via a post-frame callback, guarded by `_currencyAutoSelected`. The BLoC's silent-drop branch for amount-without-currency is no longer reachable in normal use.
- Location label on `ListingCard` (contract `my-listings-page.md § Listing card`): Resolved. Added `_LocationLabelsHost` stateful wrapper in `my_listings_page.dart` that caches `Governorate` / `Area` entities by ID across refreshes via Phase 8 `LocationsRepository.loadGovernorate` / `.loadArea`. Cards render `Governorate • Area` using the bilingual `localizedName(locale)` helper.
- Read-only preview row labels: Resolved. Migrated all hardcoded English labels (`Purpose`, `Property type`, `Address`, `Size (m²)`, etc.) to the existing Phase 4 `fieldLabel*` ARB keys. Also added governorate / area rows to the preview via the same Phase 8 lookups.
- Read-only preview enum value rendering: Resolved. `listing.purpose.toDbValue()` and `listing.propertyType.toDbValue()` were rendering raw db strings (`sale`, `apartment`). Lifted the existing `_purposeLabel` / `_propertyTypeLabel` helpers from `step_basics.dart` to a shared `lib/features/listing_form/presentation/util/listing_enum_labels.dart` so both step-basics and read-only preview use the same locale-aware labels.
- Constitution VI design-token grep audit: Resolved. Two occurrences of `EdgeInsets.only` in `step_review.dart` migrated to `EdgeInsetsDirectional.only` for RTL safety. T117 audit clean.
- `_TodoPhase10Placeholder` removed from `app_router.dart`: Resolved. Both Create and My Listings routes now resolve to real pages.

## Accepted As-Is For Phase 10

- Date format on listing cards is plain ISO `YYYY-MM-DD`: Accepted for v1. Arabic-Indic digit conversion still happens via the digit pipeline when rendered inside an `ar`-locale subtree, but the underlying format is not locale-aware (no `intl.DateFormat`). Locale-aware date formatting can come as a cosmetic pass in a later spec.
- Individual `loadGovernorate(id)` / `loadArea(id)` round-trips for `_LocationLabelsHost`: Accepted. Each unique ID in the current page of listings is one PostgREST round-trip. At MVP scale this is bounded (≤ 14 governorates, ≤ 10 seeded areas in Damascus per Phase 8 inventory) and the cache survives the session. A future Phase 8 batch endpoint would replace this with one round-trip.
- `submit_listing` as a SECURITY DEFINER PL/pgSQL RPC (not an Edge Function): Accepted per R-06 (Phase 7/9 carry-forward). Permission checks live inside the RPC body; advisor flags the function but the design is intentional and Phase 9 / Phase 10 ship it the same way.
- Phase 10 deviates from Phase 8/9's anonymous-SELECT carve-out: Accepted per R-04. Listings are not global reference data; public-read is gated on `status='approved'` AND the publish-window-open predicate. Anonymous reads of non-approved listings are explicitly denied.
- `listings.agency_id` ships without an FK constraint: Accepted per R-17. Phase 19 introduces `public.agencies` and will add the FK then.

## Deferred

- End-of-spec batch device walk (T081, T081a, T082, T083, T101, T102, T103, T104, T105, T106, T107, T108, T109, T110, T111, T119): Deferred to a single comprehensive device session per user direction. The full `quickstart.md` recipe (Steps 1-14) executes all P1/P2 verifications in proper order, including SC-001 timing, three-layer non-approved gate, append-only history, status-walk audit emission, single-currency invariant, mid-session publisher-status approval propagation.
- Phase 11 media-picker integration: Deferred. Phase 10 ships step 6 of the form as `step_media_placeholder.dart` rendering a localized banner; Phase 11 will replace it with the actual `MediaPicker` widget against `public.listing_media` + storage policies for `listing-images` / `listing-videos`.
- Phase 12 `reject_listing.reason` write path: Deferred. Phase 10's status-transition trigger writes history rows with `reason=NULL`. Phase 12's `reject_listing` RPC will populate the reason on the most-recent history row (either via UPDATE-from-trigger-context or via a separate INSERT-side-effect — Phase 12's design choice).
- Phase 15 pin-drop edit for `listings.latitude` / `longitude`: Deferred. Phase 10 ships area-centroid auto-fill only per Q2 — the publisher cannot override the centroid in v1. Phase 15 will add a map-based pin-drop edit affordance.
- Phase 19 `listings.agency_id` FK constraint: Deferred. Phase 19 introduces `public.agencies` and will `ALTER TABLE public.listings ADD CONSTRAINT ... FOREIGN KEY (agency_id) REFERENCES public.agencies(id) ON DELETE SET NULL` once the table exists.
- Phase 22 PermissionChecker cache + Realtime revisit: Deferred per the `project_phase22_perm_cache_revisit.md` memory. Phase 10's mutation surface adds another data point worth examining when Phase 22 introduces Realtime subscriptions.
- Post-approval edit flow for `status='approved'` listings: Deferred. v1 shows the `approvedNotEditableMessage` banner; a future spec will own the design + RPC for editing approved listings (likely with admin re-approval).
- Area-centroid backfill flow when admins add new areas post-Phase-10: Deferred. The seed inventory in migration 1 covers the 10 Damascus areas Phase 8 ships with; new areas added via the Phase 8 admin UI in the meantime have NULL centroids and the form blocks at the location step via `validatorAreaMissingCentroid`. A future admin flow could prompt for the centroid at area-creation time.
