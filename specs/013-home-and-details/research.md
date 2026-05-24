# Phase 13 — Research

**Status**: All decisions locked plan-time (2026-05-23). Resolves every plan-time NEEDS-CLARIFICATION; carries forward Phase 1–12 invariants by reference.

This file picks up from Phase 12's R-41..R-60 numbering. Phase 13 adds R-61 through R-72 (12 new decisions). Invariants R-01..R-40 (Phases 1–11) + R-41..R-60 (Phase 12) are inherited unchanged unless explicitly amended below.

## Carried-forward invariants (no edit in Phase 13)

- **R-05** (Phase 4 `log_audit()` byte-identical reuse, NARROWLY RELAXED per Phase 12 Q7=A): Phase 13 ships zero new `log_audit()` call sites. The function body is consumed unchanged per the relaxed invariant.
- **R-14** (Phase 11's stable `listing_media.id` UUIDs across rejected→draft round-trip): Phase 13's `cached_network_image` cache key is the `getPublicUrl()` URL; URLs are stable for the lifetime of the bucket object per R-14 + R-29.
- **R-29** (Phase 11's `getPublicUrl()` URL stability + consumption pattern): Phase 13 actively consumes this pattern at the public surface for the first time via the Phase 12 Q8=A `ListingGallery` widget.
- **R-35** (Phase 11's prior-phase-migration-file immutability): Phase 13 ships ONE new migration; Phase 1–12 migration files remain unedited. The Phase 10 listings migration is NOT amended to add the indexes — instead a fresh Phase 13 migration carries the four `CREATE INDEX` statements.
- **R-53** (Phase 12's BLoC ownership boundary): Phase 13's `ListingDetailsBloc` is INDEPENDENT of Phase 12's `ListingPreviewBloc`. Verified by inspection (no shared BLoC import path). Validated below at R-70.

## New Phase 13 decisions

### R-61 — Index migration filename + ordering

**Decision**: Single migration file at `supabase/migrations/20260524120001_create_listings_indexes.sql` (date-prefix convention established by Phases 8–12; the `20260524` date assumes Phase 13 implementation happens on 2026-05-24 the day after Phase 13 spec; if implementation slips by days the filename's date is bumped to match per the project's convention). The migration applies via Supabase MCP `apply_migration` with the migration name `create_listings_indexes` — name MUST be unique per project memory `project_supabase_mcp_apply_migration.md`. Migration body contains four `CREATE INDEX IF NOT EXISTS` statements in order: status_published_at, status_created_at, governorate_status, property_type_status.

**Rationale**: Idempotency via `IF NOT EXISTS` per the project convention. Date-prefix filename matches Phases 8–12 precedent. The `create_listings_indexes` name is descriptive AND unique within `public.migrations` tracker rows.

**Alternatives considered**: Amend Phase 10's `0016_create_listings.sql` migration to add the indexes inline — REJECTED per R-35 (Phase 11's prior-phase-immutability invariant). Ship indexes via a Phase 14 prerequisite migration — REJECTED because Phase 14 has not yet been spec'd AND Phase 13's home-feed read pattern needs the indexes immediately.

### R-62 — Cursor wire format *(corrected at /speckit-analyze 2026-05-23 — earlier draft had a tied-`published_at` correctness bug)*

**Decision**: Cursor encoded as a tuple `(DateTime publishedAt, String id)` in the BLoC state, marshaled to the Supabase client query as **a single PostgREST `.or()` filter** expressing the lexicographic strict-less-than tuple compare:

```dart
supabase.from('listings')
  .select(...)
  .or(
    'published_at.lt.${cursor.publishedAt.toIso8601String()},'
    'and(published_at.eq.${cursor.publishedAt.toIso8601String()},id.lt.${cursor.id})'
  )
  .order('published_at', ascending: false)
  .order('id', ascending: false)
  .limit(20);
```

The `.or()` filter expresses the SQL predicate `(published_at < X) OR (published_at = X AND id < Y)` — the correct lexicographic strict-less-than for the tuple `(published_at, id)`. This is the ONLY predicate that produces no-duplicate AND no-skip pagination under tied `published_at` values. The cursor is NOT exposed in any URL or persisted across app launches — it lives only in `HomeBloc` state.

**Why the earlier "two `.lt()` filters" approach was wrong** *(documented for future reviewers)*: A naive `.lt('published_at', X).lt('id', Y)` chains as `WHERE published_at < X AND id < Y`. This EXCLUDES any row with `id >= Y` regardless of `published_at`, which causes massive data loss in pagination — rows that should appear on page N+1 are silently dropped. A single `.lt('published_at', X)` (without `.lt('id', ...)`) also fails: when page N ends mid-cluster of rows sharing `published_at = X`, the remaining rows in that cluster are skipped on page N+1.

**Rationale for `.or()` over alternatives**: PostgREST does NOT support tuple comparisons via SDK chaining (no `(a, b) < (x, y)` syntax), but `.or()` with a nested `and()` expresses the exact predicate. Cursor lives in-memory only; opaque encoding is not needed because the cursor never crosses an API boundary.

**Alternatives considered**: (a) base64-encoded JSON cursor — REJECTED (opaque encoding for zero portability benefit since the cursor is in-memory-only). (b) Offset pagination via `range(start, end)` — REJECTED because offset pagination breaks under concurrent writes (a Phase 12 approval mid-session shifts every subsequent page by one row, causing duplicates or skips); the spec's US5 explicitly requires no-duplicate / no-skip. (c) Two-roundtrip BLoC union (issue `published_at < X` AND `published_at = X AND id < Y` as two separate queries, union client-side, sort, take 20) — REJECTED for the extra round-trip cost on Syrian 4G; the single `.or()` query is equivalent and faster. (d) Realtime subscription replacing pagination — REJECTED per the "Folded default — Realtime subscription" in spec.md which defers Realtime to Phase 22.

### R-63 — Home-feed SELECT projection shape

**Decision**: The home-feed SELECT issues a single PostgREST query with embedded selects:

```dart
supabase.from('listings')
  .select('''
    id, title, property_type, purpose, governorate_id, city_id, published_at,
    listing_prices!inner(currency_code, amount, is_primary),
    listing_media(storage_path, ordering, is_main, kind),
    governorate:governorates(name_ar, name_en),
    city:cities(name_ar, name_en)
  ''')
  .order('published_at', ascending: false)
  .order('id', ascending: false)
  .limit(20);
```

The cursor filters from R-62 are appended when `cursor != null`. The `listing_prices!inner` join with `.eq('is_primary', true)` is added as a `.eq()` on the embedded select (PostgREST syntax) to select only the primary price row per listing. The `listing_media` embedded select is filtered to `is_main=true AND kind='image'` for the home card thumbnail. The `governorate` + `city` embedded selects are renamed via PostgREST's alias syntax for type-safety in the Dart DTO mapping.

**Rationale**: A single round-trip avoids N+1 query patterns. Embedded selects honor the public-read RLS on each child table (Phase 10's `listing_prices` + Phase 8's `governorates`/`cities` policies). No application-layer `status='approved'` filter is added — RLS is the sole gate per FR-018. `area_id` is omitted from the projection because the card surface shows only governorate + city per FR-017 (area-level granularity is reserved for the details page).

**Alternatives considered**: (a) Separate queries for prices/media/locations + client-side join — REJECTED for the N+1 round-trip cost on Syrian 4G. (b) A materialized view `mv_listings_home_feed` precomputing the join — REJECTED for v1; deferred to a future spec if Q5=A latency budget is breached repeatedly per the Q5=A folded mitigation list. (c) Selecting only IDs + lazy-loading per card — REJECTED because the per-card lazy-load would itself be N round-trips, defeating the cursor pagination's throughput.

### R-64 — Listing-details SELECT projection shape

**Decision**: The details page SELECT issues a single PostgREST query with embedded selects covering the full aggregate:

```dart
supabase.from('listings')
  .select('''
    id, title, property_type, purpose, governorate_id, city_id, area_id,
    phone, whatsapp, contact_name_visibility, location_visibility,
    area_size, rooms, bathrooms, floor, published_at,
    listing_details(description, amenities, year_built, furnished, parking),
    listing_prices(currency_code, amount, is_primary, created_at),
    listing_media(id, storage_path, ordering, is_main, kind, external_url),
    governorate:governorates(name_ar, name_en),
    city:cities(name_ar, name_en),
    area:areas(name_ar, name_en),
    publisher:profiles!listings_publisher_user_id_fkey(full_name, username)
  ''')
  .eq('id', listingId)
  .maybeSingle();
```

The `.maybeSingle()` returns `null` when RLS hides the row OR the listing doesn't exist — both cases map to the FR-024 "Listing not found" state. The `publisher` embedded select reads only `full_name` + `username` (publicly-visible profile fields) — private fields (`legal_name`, `national_id`, `private_contact_methods` from ADR-0001 Vault columns) are NOT projected; Phase 5 RLS on `public.profiles` would block them anyway, but the explicit projection prevents accidental exposure.

**Rationale**: One round-trip for the full aggregate. The `phone` + `whatsapp` columns are projected because the Q2=A Contact-block CTA labels reference them (e.g., "Call Khaled" / "WhatsApp Khaled" — although Q2=A means the CTAs stub-to-snackbar, the publisher's display name appears in the label). The `contact_name_visibility` + `location_visibility` fields gate which versions of these fields render to anonymous users — the details page MUST respect these flags. Plan-time research codifies the exact visibility branching in the data-model.md.

**Alternatives considered**: (a) Separate query for the publisher profile — REJECTED for N+1 cost. (b) Lazy-load amenities / description below-the-fold — REJECTED for UX (user often scrolls fast; lazy-load causes visible content shifts). (c) Cache the aggregate in `cached_network_image`-style local storage — DEFERRED to a future spec; v1 re-fetches on each navigation.

### R-65 — Reuse Phase 2 `ListingCard` widget vs. ship Phase-13-specific `HomeListingCard`

**Decision**: Ship a NEW Phase-13-specific widget `lib/features/home/presentation/widgets/home_listing_card.dart` rather than reusing Phase 2's shared `lib/shared/presentation/widgets/listing_card.dart` (if it exists per the Phase 2 component-library contract). The two cards differ in concrete projection: Phase 2's generic `ListingCard` was designed for the design-token gallery + a TBD listing surface; Phase 13's `HomeListingCard` consumes the specific `HomeListingCard` domain entity from R-63's projection (flattened shape with embedded governorate name + primary price + main image storage_path). Reuse would require either (a) widening Phase 2's `ListingCard` to accept the projected shape (cross-feature coupling), or (b) translating the projection at the page boundary (defeats the projection's flatness).

**Rationale**: Avoids cross-feature coupling. Phase 13's card surface is genuinely Phase-13-specific (different from any future admin / publisher / agency surface that may reuse a different shape). Phase 2's `ListingCard`, if it exists as a generic, remains available for other feature consumers without forcing Phase 13 to adapt.

**Alternatives considered**: Reuse Phase 2's `ListingCard` verbatim — REJECTED above. Ship Phase 13's card under `lib/shared/presentation/widgets/` for forward sharing — REJECTED because Phase 13 has no second consumer for this card surface (Phase 14 ships its own search-result card shape); ship-when-needed is the cleaner Constitution-IV / IX posture.

### R-66 — Shimmer / skeleton-loader plugin choice

**Decision**: Use the gallery's existing Phase 12 Q8=A `ListingGallery` widget placeholder (a centered `CircularProgressIndicator` per the widget's contract; OR whatever Phase 12 actually shipped — plan-time inspection at implementation confirms). For the home-feed card's image placeholder, use `cached_network_image`'s built-in `placeholder` builder rendering a Phase-2-token-styled `Container(color: Theme.of(context).colorScheme.surfaceContainerHighest)` of the same aspect ratio. **No new shimmer plugin** is added in Phase 13.

**Rationale**: The spec's folded image-loading default mentions a shimmer skeleton OR a `CircularProgressIndicator` fallback; the latter is simpler + zero-dependency. A dedicated `shimmer` package would add a transitive surface for marginal UX benefit on Syrian 4G where image-load time dominates perceived loading anyway. Future spec MAY introduce a shimmer plugin if user testing shows the static placeholder is jarring.

**Alternatives considered**: Add `shimmer: ^3.x` package — REJECTED above. Ship a custom `ShimmerBox` widget in `lib/core/widgets/` — DEFERRED to a future spec.

### R-67 — Time-since-publish formatter source

**Decision**: Use the `intl` package's `RelativeDateTime` API (via `package:intl/intl.dart`'s relative-time formatting) for time-since-publish labels on the home card. The Phase 3 dependency already includes `intl`; Phase 13 is the first project consumer of the relative-time API. The Dart call shape: `intl.format(DateTime.now().difference(publishedAt))` with the current locale from `AppLocalizations.of(context).localeName`. For locales `ar` + `en`, `intl` produces "before 3 hours" / "3 hours ago" idiomatic phrasing.

**Rationale**: `intl` is already a Phase 3 dependency; avoiding a new package. The Arabic relative-time formatting is locale-aware (handles dual + plural number agreement). If `intl`'s output is awkward for any specific case (e.g., "1 minute ago" in Arabic), Phase 13 MAY fall back to manually-localized ARB keys (`time_since_just_now`, `time_since_minutes`, `time_since_hours`, `time_since_days`) — plan-time-decided at implementation OR deferred to a follow-up polish PR. Initial baseline: use `intl` natively + reserve ~4 ARB fallback keys.

**Alternatives considered**: (a) Hand-localize all relative-time strings via ARB keys — REJECTED because `intl` handles plural agreement automatically. (b) Use `timeago` package — REJECTED because it adds a new dependency for what `intl` already covers.

### R-68 — `ListingNotFoundFailure` Dart type

**Decision**: Add a new Failure subtype `ListingNotFoundFailure` to `lib/core/errors/failure.dart` (Phase 1 file extended by Phase 12 with 5 Failure subtypes — Phase 13 adds one). The `ListingDetailsBloc` emits state `ListingDetailsState(status: notFound, failure: ListingNotFoundFailure())` when the data source returns `null` from `.maybeSingle()`. The UI's switch on `state.status` renders the localized "Listing not found" + "Return to home" CTA per FR-024.

**Rationale**: Distinguishes "not found" from generic network errors at the BLoC layer for cleaner UI mapping. The failure carries no payload — the page renders a static localized state.

**Alternatives considered**: Reuse a generic `NotFoundFailure` if Phase 5+ already added one — accepted IF such a type exists at plan-time inspection (R-68 fallback). Plan-time grep at implementation: `grep -R "class.*NotFoundFailure" lib/core/errors/`.

### R-69 — `AppRoutes.shellHome` rename approach

**Decision**: Rename `AppRoutes.shellHome` → `AppRoutes.home` AND `AppRouteNames.shellHome` → `AppRouteNames.home` in the same Phase 13 PR, BUT retain a `static const shellHome = home;` alias for one-PR-lifetime back-compat. The alias is removed in a follow-up housekeeping PR after the wider rename has settled across all consumers. Reason: Phase 5–12 consumers reference `AppRoutes.shellHome` from multiple redirect call sites (post-sign-in, post-sign-out, post-submit). Renaming every consumer atomically risks merge conflicts with any in-flight branch; the alias gives a one-cycle grace window.

**Rationale**: Atomic rename safest but high blast-radius; alias-then-deprecate is the standard refactor pattern.

**Alternatives considered**: Rename atomically without alias — REJECTED for the merge-conflict risk. Keep `shellHome` as the canonical name forever — REJECTED because the name no longer accurately describes the route (it's no longer a "shell" but the public home).

### R-70 — `ListingDetailsBloc` vs Phase 12's `ListingPreviewBloc` separation

**Decision**: Phase 13's `ListingDetailsBloc` is a STANDALONE class at `lib/features/listing_details/presentation/bloc/listing_details_bloc.dart` with its OWN events / states / use case dependency (`LoadListingDetails`). No shared base class with Phase 12's `ListingPreviewBloc`. The two BLoCs fetch via different data sources — Phase 12's preview is admin-only (`listings.view_all` permission); Phase 13's details is anonymous-public (RLS-only). The two BLoCs MAY share a common domain entity (Phase 13's `ListingDetailsAggregate` may eventually be reused by Phase 12 if a refactor consolidates; but in Phase 13 the entity is Phase-13-owned).

**Rationale**: Phase 12 R-53 explicitly forward-stated this separation. Sharing a base class would couple the two BLoCs in ways that prevent future independent evolution (e.g., Phase 14 may add publisher_lookup metadata to Phase 13's details that Phase 12's preview doesn't need).

**Alternatives considered**: Share an abstract `ListingPageBloc` base class — REJECTED above.

### R-71 — `DeepLinkAwareBackButton` widget vs inline helper

**Decision**: Ship the Q4=D conditional-back-button pattern as an INLINE helper inside `lib/features/listing_details/presentation/pages/listing_details_page.dart` for Phase 13. Encapsulation as a reusable widget at `lib/core/widgets/deep_link_aware_back_button.dart` is DEFERRED to whichever later phase (Phase 14 search-result-detail page, Phase 15 map listing popover, Phase 22 push-deep-link target) introduces the SECOND consumer of the pattern.

**Rationale**: Constitution requires no premature abstraction. Phase 13 has ONE consumer of the Q4=D pattern; abstracting now is speculative. The inline helper is ~10 lines of Dart (an `IconButton` + a `PopScope` wrapper). When the second consumer arrives, the abstraction is straightforward.

**Alternatives considered**: Ship the reusable widget now — REJECTED above. Ship the pattern as a `mixin DeepLinkAwareBackMixin` — REJECTED for the same reason.

### R-72 — Two-device manual verification matrix per user story

**Decision**: The manual verification matrix for Phase 13's quickstart assigns devices as follows:

| User Story | Primary device | Secondary device | Rationale |
|---|---|---|---|
| US1 (anonymous browse home feed) | Infinix Note 8 | Pixel 8 Pro emulator | Primary target user is the Syrian anonymous browser on Helio G80 mid-tier hardware. |
| US2 (listing details + gallery swipe + video tap) | Infinix Note 8 | Pixel 8 Pro emulator | Same persona. Video-tap external launch verified with VLC on Infinix Note 8 + Chrome on emulator. |
| US3 (authenticated browsing same flows) | Pixel 8 Pro emulator | Infinix Note 8 | Authenticated browsing is the secondary persona; emulator is faster for sign-in / sign-out cycles. |
| US4 (RLS verification end-to-end) | Infinix Note 8 (anon) + Pixel 8 Pro emulator (admin SQL workspace) | — | Two-device required: anonymous browser observes filter, admin device runs SQL via Supabase MCP. |
| US5 (cursor pagination correctness under concurrent writes) | Two devices — Infinix Note 8 (browse) + Pixel 8 Pro emulator (admin approve via Phase 12 UI) | — | Concurrent-write requires simultaneous devices. |
| US6 (visual + design-token compliance) | Infinix Note 8 + Pixel 8 Pro emulator | — | Both devices must visually pass in light/dark × ar/en. |
| Q4=D back-button deep-link | Infinix Note 8 | Pixel 8 Pro emulator | `adb shell am start` deep-link test on both. |
| Q6=A background→foreground resume | Infinix Note 8 | Pixel 8 Pro emulator | Test 1-minute + 30-minute backgrounding on both. |

The Infinix Note 8 is the PRIMARY device for Phase 13 anonymous-browse paths (matches user memory `user_test_device.md` — the primary physical device for AlNujom QA). The Pixel 8 Pro emulator covers newer-Android edge cases (API 34/35) AND faster sign-in/sign-out cycles for authenticated paths.

**Rationale**: Matches the project's established two-device manual verification posture (Phase 11 + Phase 12 both used this matrix shape). The device assignments invert from Phase 12 because Phase 13's primary persona is the anonymous browser, not the admin.

**Alternatives considered**: Single-device verification on Infinix Note 8 only — REJECTED because newer-Android routing edge cases (Pixel 8 Pro Android 14) may surface differently AND the concurrent-write test requires two devices. Single-device on Pixel 8 Pro emulator only — REJECTED because the Infinix Note 8 is the binding hardware target per Constitution XI + user memory.
