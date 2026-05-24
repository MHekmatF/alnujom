# Implementation Plan: Public Home & Listing Details

**Branch**: `013-home-and-details` | **Date**: 2026-05-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/013-home-and-details/spec.md`

## Summary

Phase 13 introduces the project's **first anonymous-facing UI surfaces** — the public `HomePage` at `/` (replacing Phase 1's `ShellHomePage`) AND the public `ListingDetailsPage` at `/listings/:id` — which together consume the rows that Phase 12's `approve_listing` Edge Function writes. The phase is a **pure-read surface**: zero new tables, zero new RLS policies, zero new Edge Functions, zero new permission keys, zero new audit-log call sites. Phase 13 ships exactly **one new SQL migration** (`0022_listings_indexes.sql`) introducing four composite indexes on `public.listings` to support the home-feed read pattern (`(status, published_at DESC, id DESC)`), the IMPLEMENTATION-PLAN-named pattern (`(status, created_at DESC, id DESC)`), and two facet-prep patterns (`(governorate_id, status)`, `(property_type, status)`); **one new feature folder** at `lib/features/home/` carrying full three-layer Clean Architecture (data + domain + presentation) + the `HomeBloc` driving cursor pagination with page size 20 ordered by `(published_at DESC, id DESC)` per the spec's folded pagination default; **one new feature folder** at `lib/features/listing_details/` carrying full three-layer Clean Architecture + the independent `ListingDetailsBloc` per Phase 12 R-53 BLoC ownership boundary; **the routing rewire** at `lib/core/routing/app_router.dart` binding `/` to `HomePage` (no longer `ShellHomePage`) + adding `/listings/:id` for deep-link entry; **the deletion** of `lib/shell/shell_home_page.dart` + the `lib/shell/` directory per Phase 1's forward-stated contract; **a ~25-key ARB delta** to `lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb` covering HomePage chrome + Q1=A stub snackbars + ListingDetailsPage chrome + the six Q2=A Coming-soon snackbars + the two Q3=A reserved auth-required-CTA keys + error states + empty states + time-since-publish suffixes; **one new pubspec.yaml package** (`url_launcher`) introduced for the FR-027 video-tap external-player launch (resolving Phase 11's deferred external-player item) AND no other functional contact wiring per Q2=A; **the active consumption of the Phase 12 Q8=A shared display widgets** at `lib/shared/presentation/widgets/listing_display/` (`ListingGallery`, `ListingPriceBlock`, `ListingLocationBlock`, `ListingAmenitiesBlock`, `ListingDescriptionBlock`) — imported verbatim by the new `ListingDetailsPage`, no edits to the widget files; **the first public-surface consumption** of Phase 1's `cached_network_image` package via the `ListingGallery` widget rendering Phase 11's `getPublicUrl()` URLs.

**Technical approach**: The six Q-resolutions from spec.md close the design space — Q1=A (hero search bar + property-type shortcuts surface localized "Coming soon" snackbars; no navigation in Phase 13), Q2=A (all six listing-details CTAs are uniform Coming-soon stubs; no `tel:` / `wa.me/` / share-sheet wiring in Phase 13), Q3=A (anonymous-tap on auth-required CTA pattern codified as a forward-state convention for later phases; Phase 13 reserves ARB keys for the first future consumer), Q4=D (`ListingDetailsPage` back-arrow conditional behavior — `Navigator.canPop()` ? pop : `context.go(AppRoutes.home)` — handles deep-link entry without exiting the app), Q5=A (≤ 2 sec p95 steady-state interaction latency budget for infinite-scroll page-load + pull-to-refresh, matching Phase 12 Q6=A), Q6=A (NO auto-refresh on background→foreground resume; HomeBloc state cached; user pulls-to-refresh manually). The Phase 13 PR collapses into **one mandatory SQL migration** (indexes only) + **one new pubspec dep** (`url_launcher`) + **two new feature folders** + **one shared-widget consumption surface** (no widget edits) + **one routing rewire** + **one ARB delta**. **Manual UI verification only** per `feedback_no_new_tests.md` (the tenth phase to follow the no-new-tests rule).

The forward-stated Phase 13 contracts from Phase 1 (`ShellHomePage` replacement), Phase 11 (external-player launch + public-URL gallery consumption + storage-RLS end-to-end verification at the read path), Phase 12 (Q8=A shared widgets reuse + R-53 independent BLoC + public-read RLS end-to-end verification at the UI layer + the `published_at` writer's downstream consumer), Phase 9 (`MoneyFormatter` + cross-currency on cards), Phase 8 (governorate/city/area names on cards + details), Phase 5 (auth-state observation for empty-state CTAs + Q3=A forward convention) — all collapse into this single Phase 13 PR.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel) for the entire Phase 13 surface; PostgreSQL (Supabase remote, Postgres 15+) for the one new SQL migration. **No TypeScript Edge Function additions** (Phase 13 is a pure-read surface; reads flow through PostgREST + RLS directly). **One new pubspec package** added in Phase 13 (`url_launcher`); two contingent packages explicitly NOT added (`share_plus` per Q2=A FR-033; a shimmer plugin per the folded image-loading default — only added if Phase 2's existing token surface lacks a shimmer primitive, plan-time-codified per R-66 below).

**Primary Dependencies**: All existing packages consumed unchanged — `supabase_flutter` (Phase 13 uses `Supabase.instance.client.from('listings').select(...)` for the home-feed query + the details query; both go through Phase 1's `lib/core/network/supabase_client.dart` wrapper), `flutter_bloc` (two new BLoCs in Phase 13: `HomeBloc`, `ListingDetailsBloc` — both independent per Phase 12 R-53), `equatable`, `get_it` + `injectable` (DI registrations for the new datasources / repositories / use cases / BLoCs — generated via `build_runner` as usual), `go_router` (one rewire of `/` builder + one new `/listings/:id` route in `lib/core/routing/app_router.dart`; the route name + path constants are added per FR-008 / FR-010), `intl` (the time-since-publish formatter on the home card via `RelativeDateFormat` — Phase 3 dependency consumed for the first time in Phase 13), `cached_network_image` (Phase 1 dependency — Phase 13 is the FIRST consumer at a public surface; the `ListingGallery` widget shipped by Phase 12 calls `CachedNetworkImage(...)` against the `getPublicUrl()` URLs from Phase 11), `flutter_localizations` (for `RelativeDateFormat` localization). **One new pubspec package**: `url_launcher` (per FR-032; consumed ONLY by the `ListingGallery`'s video-item tap-handler per FR-027 — `url_launcher.launchUrl(Uri.parse(<video-public-url>), mode: LaunchMode.externalApplication)`). The package is vendored-pure-Dart at `^6.x` (latest stable as of plan-time; exact version locked in pubspec.lock at implementation). No Google / Firebase transitive dependency per the Syrian-network safety check.

**Tooling**: Supabase MCP server (`apply_migration` for the new index migration; `execute_sql` for the EXPLAIN verification; `list_tables` to confirm zero schema delta on the six listings-domain tables). **Zero use** of MCP `deploy_edge_function` (Phase 13 ships no Edge Functions; Phase 12's two Edge Functions are the listings-domain set at v1 launch). Flutter analyzer + the Phase 3 localization lint guard for static validation. Manual verification via the two-device walk (Infinix Note 8 publisher device + Pixel 8 Pro emulator anonymous browse device — actually for Phase 13 the device assignments invert from Phase 12 because the primary persona is the anonymous browser, not the admin: the Infinix Note 8 is the primary anonymous-browse device given its closer match to the typical Syrian end-user hardware; the Pixel 8 Pro emulator is the supplementary newer-Android-edge-case device).

**Storage**: Remote Supabase Postgres project. Phase 13 backend artifacts:

- **One mandatory new migration**: `<timestamp>_create_listings_indexes.sql` per FR-001 — four `CREATE INDEX IF NOT EXISTS` statements:
  - `CREATE INDEX IF NOT EXISTS idx_listings_status_published_at ON public.listings (status, published_at DESC, id DESC);`
  - `CREATE INDEX IF NOT EXISTS idx_listings_status_created_at ON public.listings (status, created_at DESC, id DESC);`
  - `CREATE INDEX IF NOT EXISTS idx_listings_governorate_status ON public.listings (governorate_id, status);`
  - `CREATE INDEX IF NOT EXISTS idx_listings_property_type_status ON public.listings (property_type, status);`
- **Zero schema edits** to `public.listings`, `public.listing_details`, `public.listing_prices`, `public.listing_media`, `public.listing_visibility`, `public.listing_status_history`. No ALTER TABLE, no CREATE TABLE, no DROP TABLE. Plan-time grep confirms.
- **Zero new RLS policies**. Phase 10's public-read policy on `public.listings` is the sole gate; Phase 11's `listing_media` + storage-bucket policies are inherited unchanged. Plan-time grep confirms.
- **Zero new permission keys**. Phase 13 is anonymous-readable via RLS; no permission check is required client- or server-side.
- **Zero new SQL functions or triggers**. The `log_audit()` function is consumed unchanged (still byte-identical except for the Phase 12 FR-024 COALESCE amendment).
- **Zero new audit-log call sites**. Reads are not audited (high-volume; would dominate the audit table).

**Edge Functions**: None added. Phase 13 reads flow through PostgREST + RLS directly. Phase 12's two functions (`approve_listing`, `reject_listing`) remain the listings-domain set at v1 launch.

**Testing**: **Manual SQL inspection against the remote Supabase project via Supabase MCP `execute_sql` + EXPLAIN verification + manual UI verification on two devices (Infinix Note 8 as the primary anonymous-browse device for the home-feed pagination + listing-details render + deep-link back-button + background-resume freshness walks; Pixel 8 Pro emulator as the supplementary Android 14 device for newer-OS routing edge cases).** Per `feedback_no_new_tests.md`, Phase 13 introduces NO new automated tests of any kind — including for the cursor pagination correctness, the conditional back-button behavior, the latency budget, the RLS-only-filter discipline, the deep-link "Listing not found" path. All verification is codified in `quickstart.md` as a manual checklist exercised against the remote Supabase project + the reference Infinix Note 8 device. Build-time validation is preserved: Supabase's static SQL parser at `apply_migration` time catches syntax errors in the index migration; Flutter's analyzer + the existing Phase 3 localization lint guard validate the new Dart files; `dart pub get` validates the `url_launcher` dependency resolution. Existing Phase 1–12 tests remain unchanged.

**Target Platform**: Android 7.0+ (API 24+) for the Flutter side (Constitution XI); Supabase remote Postgres for the backend. iOS / Web / desktop NOT a target. The `url_launcher` package's Android implementation is the only platform-specific surface Phase 13 introduces.

**Project Type**: Mobile app + backend. Phase 13 introduces TWO new feature folders under `lib/features/home/` and `lib/features/listing_details/`; ZERO new Supabase Edge Function folders; ZERO new shared-widget subdirectories (the Phase 12 Q8=A `lib/shared/presentation/widgets/listing_display/` directory is CONSUMED unchanged); ONE extended existing routing file (`lib/core/routing/app_router.dart`); ONE deleted Phase 1 surface (`lib/shell/`); ONE pubspec change (`url_launcher` add); ONE AndroidManifest change (`<queries>` element for `url_launcher`'s scheme visibility on Android 11+).

**Performance Goals**:

- HomePage cold launch to first 20 cards rendered (text + image placeholders, then images filling in): ≤ 3 seconds on the Infinix Note 8 over Syrian-realistic network conditions per SC-001. (Image-byte fill time is uncontrollable in Phase 13 — bounded by `cached_network_image` defaults + Supabase Storage egress + Syrian network.)
- HomePage infinite-scroll next-page load: ≤ 2 seconds p95 per Q5=A + SC-034. Measured at the device, gesture-to-text-appearance.
- HomePage pull-to-refresh first-page reload: ≤ 2 seconds p95 per Q5=A + SC-034. Same measurement methodology.
- ListingDetailsPage open from card tap: ≤ 1 second per SC-004 (text rendered; images filling in).
- ListingDetailsPage deep-link entry from cold launch: ≤ 3 seconds (cold-launch overhead + the page render).
- `EXPLAIN (ANALYZE, BUFFERS) SELECT ... LIMIT 20` on `public.listings` uses `Index Scan using idx_listings_status_published_at` at any row count ≥ 100 per SC-009.
- Background→foreground resume: instantaneous render from cached BLoC state; no network query issued per Q6=A + SC-035.
- Deep-link back-button tap: ≤ 100 ms to either pop or route to home per Q4=D.

**Constraints**:

- Constitution II (Source-Controlled Backend) binding: the one index migration is a checked-in `.sql` file under `supabase/migrations/`. No Studio-only edits. The migration applies via Supabase MCP `apply_migration` per project memory `project_supabase_mcp_apply_migration.md`.
- Constitution III (Security-First Supabase, NON-NEGOTIABLE): Phase 10's public-read RLS on `public.listings` is the SOLE filter — Phase 13 code MUST NOT add an application-layer `.eq('status', 'approved')` filter per FR-018 + SC-008. Plan-time grep enforces. The "Listing not found" UI path per FR-024 + SC-006 / SC-007 makes RLS-hidden rows indistinguishable from genuinely-non-existent rows from the client's perspective — no information leak. Phase 11's storage-bucket RLS is inherited; non-approved listings' images return 404/403 to anonymous callers per Phase 11 SC-008 / SC-029.
- Constitution IV (Clean Architecture Flutter): both new feature folders carry the three-layer split (`data/` + `domain/` + `presentation/`). `lib/features/home/domain/` and `lib/features/listing_details/domain/` are Supabase-free per Constitution IX. The two new BLoCs (`HomeBloc`, `ListingDetailsBloc`) keep BLoC ownership at the page boundary; per Phase 12 R-53 `ListingDetailsBloc` is INDEPENDENT of Phase 12's `ListingPreviewBloc`.
- Constitution V (Arabic-First Localization): every new user-visible chrome string flows through Phase 3's `AppLocalizations`. ~25 new ARB keys (final count plan-time-codified) cover HomePage + ListingDetailsPage chrome + the eight Q1=A / Q2=A Coming-soon snackbar keys + the two Q3=A reserved keys + error/empty states + time-since-publish suffixes (or `intl` `RelativeDateFormat` native handling, plan-time-decided per R-67). The Phase 3 localization lint guard catches any hardcoded user-facing string at PR review per SC-014.
- Constitution VI (Theme System & Design Tokens): every new widget under `lib/features/home/presentation/` AND `lib/features/listing_details/presentation/` consumes Phase 2 design tokens. The home-feed card uses `surfaceContainer` background; the hero-search-bar surface uses `surfaceVariant` with a leading magnifying-glass icon per Phase 2; the property-type chips use `secondaryContainer` background; the empty-state CTA uses `primary` token. No inline hex / font-size / padding per SC-015.
- Constitution VII (Dynamic Roles & Permissions): NOT exercised in Phase 13 — reads are anonymous-friendly via RLS, no permission keys, no permission checks, no audit emission. The `PermissionChecker` is consumed at zero new call sites in Phase 13.
- Constitution VIII (Approval Workflow & Publisher Identity): Phase 13 IS the consumer surface of Phase 12's approval workflow — the home feed shows only `status='approved'` listings via RLS; the details page renders the publisher's submitted-and-admin-approved content at full fidelity. The publisher's identity (display name) appears on the card + details page; private fields (legal name / national ID / private contact methods per Phase 5 + ADR-0001) are NOT surfaced in Phase 13 — Phase 5's RLS restricts those fields to admins-only.
- Constitution IX (Future Backend Portability): `lib/features/home/domain/` AND `lib/features/listing_details/domain/` import nothing from `package:supabase_flutter`. The new use cases (`LoadHomeFeed`, `LoadListingDetails`) are abstract Dart classes. Only `lib/features/home/data/datasources/supabase_home_feed_datasource.dart` AND `lib/features/listing_details/data/datasources/supabase_listing_details_datasource.dart` touch Supabase types. Plan-time grep confirms per SC-013.
- Constitution X (Testable AI Workflow): per `feedback_no_new_tests.md`, every FR is verifiable via a manual SQL action (EXPLAIN check) OR a manual UI walk (anonymous browse, deep-link entry, pull-to-refresh, infinite scroll, video-tap external launch) OR a plan-time grep (RLS-only filter discipline, design-token discipline, Supabase isolation discipline). The constitution permits "a SQL query with expected output" or "a UI action with expected screen state" as acceptance steps. No constitutional amendment is required.
- Constitution XI (Android-First MVP): all Flutter additions target the Android build only. The `url_launcher` package's Android implementation is consumed; iOS / web / desktop paths are NOT exercised. The two-device walk uses Infinix Note 8 + Pixel 8 Pro emulator — both Android.
- Constitution XII (No Hidden Product Decisions): all six Session 2026-05-23 clarifications (Q1=A, Q2=A, Q3=A, Q4=D, Q5=A, Q6=A) are captured in `spec.md` `## Clarifications`. Every plan-time research item (R-61..R-XX below) has a paired clarification answer or a paired FR/SC; no decision lives only in conversation.
- Migrations apply to the **remote** Supabase project via Supabase MCP `apply_migration`. The project memory `project_supabase_mcp_apply_migration.md` is binding — re-applying a migration name re-runs the SQL AND adds a duplicate tracker row, so the index migration name is unique.
- Migrations MUST be idempotent (`CREATE INDEX IF NOT EXISTS`).
- **One new pubspec package** (`url_launcher`) added (Phase 13 reverses Phase 12's zero-package posture; the pubspec change is the only externally-visible dependency delta).
- **One AndroidManifest change** — the `<queries>` element required for `url_launcher`'s scheme visibility on Android 11+ (FR-032). The element whitelists the `https:` scheme (for video URL launch) only; `tel:` and `mailto:` schemes are NOT added because Phase 13's Q2=A stubs them.
- No iOS-only code (Constitution XI).

**Scale/Scope**:

- **One mandatory new SQL migration** under `supabase/migrations/` — `<timestamp>_create_listings_indexes.sql` (FR-001). Contains four `CREATE INDEX IF NOT EXISTS` statements.
- **Zero new Edge Functions, zero new SQL functions, zero new RLS policies, zero new permission keys, zero new audit-log call sites**.
- **Two new feature folders** under `lib/features/` with full three-layer Clean Architecture:
  - `lib/features/home/` — 11 new files (see Project Structure below).
  - `lib/features/listing_details/` — 10 new files (see Project Structure below).
- **One extended existing routing file** at `lib/core/routing/app_router.dart`: the `/` builder swaps from `ShellHomePage()` to `HomePage()`; one new route `/listings/:id` is added; route NAME `AppRouteNames.shellHome` is renamed to `AppRouteNames.home` AND path constant `AppRoutes.shellHome` to `AppRoutes.home` (per the spec's folded routing default; the interim alias is plan-time-codified per R-69 below).
- **One deleted Phase 1 surface**: `lib/shell/shell_home_page.dart` AND the `lib/shell/` directory.
- **One extended existing DI file** at `lib/core/di/injection.dart`: registrations for the new datasources + repositories + use cases + BLoCs (generated via `build_runner` as usual).
- **ARB key delta** on `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`: approximately 25 new strings — HomePage chrome (~6 keys) + Q1=A snackbars (2 keys) + Q2=A snackbars (6 keys) + Q3=A reserved keys (2 keys) + ListingDetailsPage chrome (~3 keys) + error/empty states (~4 keys) + CTA labels (~6 keys); time-since-publish handled natively by `intl` `RelativeDateFormat` per R-67. The hand-maintained `_DebugAppLocalizations` subclass at `lib/l10n/app_strings.dart` is also extended per the Phase 11 DEFERRED.md forward-stated note.
- **One new pubspec package** (`url_launcher` at `^6.x`).
- **One AndroidManifest change** (`<queries>` element for `https:` scheme).
- **Zero changes** to `.github/workflows/ci.yml`.
- **Zero new tests** (durable no-new-tests rule, tenth consecutive phase).

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists with 6 user stories, 35 FRs (FR-001..FR-035), 35 SCs (SC-001..SC-035); `/speckit-clarify` Session 2026-05-23 resolved 3 additional questions (Q4 deep-link back, Q5 latency budget, Q6 background resume) on top of the 3 resolved during `/speckit-specify` (Q1 stub treatment, Q2 CTA scope, Q3 anonymous-tap convention). All 6 Qs are folded into FRs / SCs / Assumptions. No implementation has begun. |
| II. Source-Controlled Backend | **Pass** | The one Phase 13 backend artifact is a checked-in file: `supabase/migrations/<timestamp>_create_listings_indexes.sql` (FR-001). No Studio-only changes. Migration applies via Supabase MCP `apply_migration`. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | Phase 10's RLS on `public.listings` is the sole gate (no policy edits per FR-003); Phase 11's `listing_media` + `storage.objects` policies are inherited unchanged. Phase 13 code MUST NOT add an application-layer `status='approved'` filter per FR-018; plan-time grep enforces. The "Listing not found" UI path per FR-024 makes RLS-hidden rows indistinguishable from non-existent rows. No new anonymous-SELECT carve-outs. The `url_launcher` package is consumed ONLY for video-tap launching public Storage URLs (which are already RLS-protected per Phase 11). |
| IV. Clean Architecture Flutter | **Pass** | Both new feature folders carry the three-layer split. The new use cases are abstract Dart classes. The two new BLoCs (`HomeBloc`, `ListingDetailsBloc`) keep BLoC ownership at the page boundary; per Phase 12 R-53, `ListingDetailsBloc` is INDEPENDENT of Phase 12's `ListingPreviewBloc` — verified by inspection (no shared BLoC import path). |
| V. Arabic-First Localization | **Pass** | All ~25 new user-visible chrome strings flow through Phase 3's `AppLocalizations`. RTL is honored: the home card uses `EdgeInsetsDirectional`; the property-type chip row scrolls in the locale's reading direction; the deep-link back arrow mirrors per Flutter's default `Directionality`-aware Icon. The Phase 3 localization lint guard catches any hardcoded user-facing string at PR review per SC-014. The hand-maintained `app_strings.dart` debug subclass is updated per the Phase 11 forward-stated note. |
| VI. Theme System & Design Tokens | **Pass** | Every new widget under `lib/features/home/presentation/` AND `lib/features/listing_details/presentation/` consumes Phase 2 design tokens. The hero search bar uses `surfaceVariant`; property-type chips use `secondaryContainer`; home-feed card uses `surfaceContainer`; empty-state CTA uses `primary`; error states use `errorContainer` / `onErrorContainer`. No inline hex / font-size / padding per SC-015. |
| VII. Dynamic Roles & Permissions | **Pass (N/A)** | Phase 13 is anonymous-readable via RLS — zero new permission keys (SC-017), zero permission checks in Phase 13 code paths. The existing `PermissionChecker` is consumed at zero new call sites. |
| VIII. Approval Workflow & Publisher Identity | **Pass** | Phase 13 is the FIRST anonymous consumer surface of Phase 12's approval workflow. The home feed renders only `status='approved'` rows via RLS; the details page renders the publisher's submitted-and-approved content at full fidelity. The publisher's private fields are NOT surfaced (Phase 5 RLS restricts them to admins-only). The "Sign in to publish" empty-state CTA preserves the Constitution VIII contract that publishing requires an approved publisher account. |
| IX. Future Backend Portability | **Pass** | `lib/features/home/domain/` AND `lib/features/listing_details/domain/` continue to import nothing from `package:supabase_flutter`. The new use cases are abstract Dart classes. Only the two datasources touch Supabase types per SC-013. The five Q8=A shared widgets (consumed verbatim from Phase 12) already pass this check at their own ship time. |
| X. Testable AI Workflow | **Pass — Justified.** | Per `feedback_no_new_tests.md` carried forward from Phases 3–12, every FR is verifiable via a manual SQL action (EXPLAIN check) OR a Supabase MCP `execute_sql` / `list_migrations` inspection OR a two-device manual UI walk on the Infinix Note 8 + Pixel 8 Pro emulator OR a plan-time grep (RLS-only filter, design-token, Supabase isolation). The deep-link back-button behavior, the latency budget, the background-resume freshness, the cursor-pagination correctness, the RLS end-to-end UI verification — all codified in `quickstart.md` as a manual-verification checklist. The constitution explicitly permits "a SQL query with expected output" or "a UI action with expected screen state" as acceptance steps. No constitutional amendment is required. |
| XI. Android-First MVP | **Pass** | All Flutter additions target the Android Flutter build only. The `url_launcher` package's Android implementation is consumed; the `<queries>` element in AndroidManifest is Android-specific. No iOS-conditional code, no Flutter web compilation step in CI, no desktop target. The two-device walk uses Infinix Note 8 + Pixel 8 Pro emulator — both Android. |
| XII. No Hidden Product Decisions | **Pass** | All six Session 2026-05-23 clarifications (Q1 through Q6) are captured in `spec.md` `## Clarifications`. Every plan-time research item (R-61..R-72 below) has a paired clarification answer or a paired FR/SC. The Q4=D conditional back-arrow pattern is codified as a project-wide forward-state convention; the Q3=A anonymous-tap convention is similarly codified. No decision lives only in conversation. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/013-home-and-details/
├── plan.md                              # This file (/speckit-plan output)
├── research.md                          # Phase 0 — 12 locked tech decisions (R-61..R-72 — picks up from Phase 12 R-60)
├── data-model.md                        # Phase 1 — HomeListingCard + Cursor entity shapes + SELECT projections + ARB key inventory + per-FR / per-SC verification map
├── quickstart.md                        # Phase 1 — manual verification recipe: index migration apply + EXPLAIN check + two-device walk (Infinix Note 8 anon-browse + Pixel 8 Pro emulator newer-Android edge cases) + 35 SC verification map
├── contracts/                           # Phase 1 — 7 interface contracts
│   ├── phase13-index-migration.md                              # NEW — 4 composite indexes + IF NOT EXISTS idempotency + EXPLAIN expected output (FR-001, FR-002, SC-009)
│   ├── phase13-home-feed-query.md                              # NEW — SELECT projection shape + cursor encoding + RLS-only filter discipline (FR-015, FR-018, SC-008)
│   ├── phase13-listing-details-query.md                        # NEW — SELECT projection with embedded selects + RLS-only filter + "Listing not found" mapping (FR-023, FR-024, SC-006/SC-007)
│   ├── phase13-home-page-composition.md                        # NEW — AppBar + hero search + property-type chips + paginated feed + empty-state + Q1=A snackbar wiring (FR-013, FR-019, SC-029)
│   ├── phase13-listing-details-page-composition.md             # NEW — Phase 12 Q8=A widget composition order + Contact block + per-listing-action block + Q2=A snackbar wiring (FR-021, FR-026, SC-016, SC-030)
│   ├── phase13-deep-link-back-button.md                        # NEW — Q4=D conditional pattern + PopScope wrapper + DeepLinkAwareBackButton helper (FR-021, SC-033)
│   └── phase13-cta-stub-treatment.md                           # NEW — Q1=A + Q2=A unified snackbar treatment + Q3=A forward-state convention + ARB key naming (FR-013, FR-021, FR-028, SC-029/SC-030/SC-031)
├── checklists/
│   └── requirements.md                  # From /speckit-specify + /speckit-clarify (all 6 Qs resolved; checklist fully green)
├── spec.md                              # From /speckit-specify + /speckit-clarify (Q1=A stub treatment, Q2=A CTA scope, Q3=A anonymous-tap convention, Q4=D deep-link back, Q5=A latency budget, Q6=A no-auto-refresh resume)
├── tasks.md                             # Created by /speckit-tasks (NOT by /speckit-plan)
├── DEFERRED.md                          # Created during /speckit-implement; reviewed at squash-merge per project_deferred_work.md
└── HANDOFF.md                           # Created at /speckit-implement close-out (or omit if no follow-up scope)
```

### Source Code (repository root)

```text
supabase/
├── config.toml                                                            # (existing) NO CHANGE.
├── seed.sql                                                               # (existing) NO CHANGE.
├── migrations/
│   ├── (existing Phase 1–12 migrations)                                   # NO CHANGE.
│   └── <timestamp>_create_listings_indexes.sql                            # NEW per FR-001 — 4 CREATE INDEX IF NOT EXISTS statements on public.listings. (FR-001, FR-002, SC-009.)
├── functions/                                                             # (existing dir) NO CHANGE — Phase 12's approve_listing + reject_listing + Phase 5's two functions only.
├── policies/                                                              # (existing dir) NO CHANGE — Phase 10's listings policies + Phase 11's media/storage policies all inherited.
└── docs/                                                                  # (existing dir) NO CHANGE — Phase 13 is a read-side surface; the existing per-table docs already cover the indexed query patterns. (A future polish PR may update listings.md to note the new indexes; deferred to a follow-up housekeeping PR per project precedent.)

lib/
├── core/
│   ├── routing/
│   │   └── app_router.dart                                                # UPDATE — (a) `/` builder swaps from `ShellHomePage()` to `HomePage()` per FR-008; (b) one new route `/listings/:id` added per FR-010; (c) `AppRouteNames.shellHome` renamed to `AppRouteNames.home` (with interim alias per R-69); (d) path constant `AppRoutes.shellHome` renamed to `AppRoutes.home`.
│   ├── di/
│   │   └── injection.dart                                                 # UPDATE — `@injectable` annotations on the new datasources/repos/usecases/blocs auto-register via build_runner; the generated `injection.config.dart` is checked in.
│   ├── errors/
│   │   └── failure.dart                                                   # UPDATE (minor) — add `ListingNotFoundFailure` subtype consumed by `ListingDetailsBloc` per FR-024 (or reuse an existing generic NotFound failure if Phase 5+ already added one; plan-time R-68 decides).
│   ├── security/
│   │   └── permission_checker.dart                                        # NO CHANGE — Phase 13 has no new permission-checked surfaces.
│   └── network/
│       └── supabase_client.dart                                           # NO CHANGE — Phase 1 wrapper consumed verbatim; the new datasources call `.from()` through this wrapper.
├── shell/                                                                 # DELETE ENTIRE DIRECTORY per FR-009 + SC-010.
│   └── shell_home_page.dart                                               # DELETE per FR-009 — replaced by `lib/features/home/presentation/pages/home_page.dart`.
├── features/
│   ├── (existing Phase 5–12 feature folders)                              # NO CHANGE.
│   ├── home/                                                              # NEW FEATURE FOLDER per FR-012
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── supabase_home_feed_datasource.dart                     # NEW — only Phase 13 lib/features/home file importing package:supabase_flutter. Exposes `fetchPage(Cursor? cursor)` returning `List<HomeListingCard>`.
│   │   │   ├── dtos/
│   │   │   │   └── home_listing_card_dto.dart                             # NEW — DTO matching the home-feed SELECT projection shape with embedded selects from `listing_prices` (primary) + `listing_media` (main).
│   │   │   └── repositories/
│   │   │       └── home_feed_repository_impl.dart                         # NEW.
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── home_listing_card.dart                                 # NEW — flattened entity for the home-feed card (id, title, propertyType, purpose, governorate/city names, primary price, main-image storage_path, publishedAt).
│   │   │   │   └── cursor.dart                                            # NEW — value object `(DateTime publishedAt, String id)` for cursor pagination.
│   │   │   ├── repositories/
│   │   │   │   └── home_feed_repository.dart                              # NEW — abstract.
│   │   │   └── usecases/
│   │   │       └── load_home_feed.dart                                    # NEW.
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   └── home_bloc.dart                                         # NEW — events: HomeFeedLoadRequested, HomeFeedNextPageRequested, HomeFeedRefreshRequested. State: HomeState with fields (List<HomeListingCard>, HomeFeedStatus, Cursor?, Failure?).
│   │       ├── pages/
│   │       │   └── home_page.dart                                         # NEW — FR-013. Composes AppBar + _HeroSearchBar + _PropertyTypeShortcutRow + section header + paginated feed of _HomeListingCard widgets driven by HomeBloc.
│   │       └── widgets/
│   │           ├── hero_search_bar.dart                                   # NEW — Phase 2-token-styled surface; tap surfaces `home_search_coming_soon` snackbar per Q1=A.
│   │           ├── property_type_shortcut_row.dart                        # NEW — horizontal scroll of 8 chips; each tap surfaces `home_property_shortcut_coming_soon` snackbar embedding the type label per Q1=A.
│   │           └── home_listing_card.dart                                 # NEW — FR-017. Main image (cached_network_image on getPublicUrl) + title (2-line ellipsis) + type/purpose badges + governorate/city + primary price (MoneyFormatter in display_currency) + time-since-publish (intl RelativeDateFormat). Tap routes to `/listings/:id`.
│   ├── listing_details/                                                   # NEW FEATURE FOLDER per FR-020
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── supabase_listing_details_datasource.dart               # NEW — only Phase 13 lib/features/listing_details file importing package:supabase_flutter. Exposes `fetchListing(String id)` returning `ListingDetailsAggregate?` (null on RLS-hidden or non-existent).
│   │   │   ├── dtos/
│   │   │   │   └── listing_details_aggregate_dto.dart                     # NEW — DTO matching the details SELECT projection with embedded selects from listing_details + listing_prices + listing_media + governorate/city/area.
│   │   │   └── repositories/
│   │   │       └── listing_details_repository_impl.dart                   # NEW.
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── listing_details_aggregate.dart                         # NEW — composes Phase 10's Listing + ListingDetails + List<ListingPrice> + List<ListingMedia> + Phase 8's Governorate/City/Area.
│   │   │   ├── repositories/
│   │   │   │   └── listing_details_repository.dart                        # NEW — abstract.
│   │   │   └── usecases/
│   │   │       └── load_listing_details.dart                              # NEW.
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   └── listing_details_bloc.dart                              # NEW — independent of Phase 12's ListingPreviewBloc per R-53. Events: ListingDetailsLoadRequested(id), AuthStateChanged, RetryRequested. State: ListingDetailsState with the aggregate + status + failure.
│   │       ├── pages/
│   │       │   └── listing_details_page.dart                              # NEW — FR-021 + Q4=D conditional back. Composes AppBar (back-arrow only, Q4=D wiring) + ListingGallery + title + ListingPriceBlock + ListingLocationBlock + _ContactBlock + ListingAmenitiesBlock + ListingDescriptionBlock + _PerListingActionBlock. Wrapped in PopScope for Android system back per Q4=D.
│   │       └── widgets/
│   │           ├── contact_block.dart                                     # NEW — three Q2=A-stubbed CTAs (Call / WhatsApp / Send inquiry); each tap surfaces the corresponding Coming-soon snackbar per FR-021.
│   │           ├── per_listing_action_block.dart                          # NEW — three Q2=A-stubbed CTAs (Favorite / Share / Report); each tap surfaces the corresponding Coming-soon snackbar.
│   │           └── deep_link_aware_back_button.dart                       # NEW (or inline helper in listing_details_page.dart per R-71) — encapsulates the Q4=D conditional `if (Navigator.canPop()) Navigator.pop(); else context.go(AppRoutes.home)` pattern for reuse by every later-phase deep-link-targetable page.
└── l10n/
    ├── app_ar.arb                                                         # UPDATE — ~25 new ARB keys per FR-028.
    ├── app_en.arb                                                         # UPDATE — ~25 new ARB keys per FR-028.
    └── app_strings.dart                                                   # UPDATE — hand-maintained _DebugAppLocalizations subclass extended with the new getters per the Phase 11 DEFERRED.md forward-stated note.

pubspec.yaml                                                               # UPDATE — add `url_launcher: ^6.x` dependency per FR-032.
pubspec.lock                                                               # UPDATE — generated by `flutter pub get` after pubspec.yaml change.
android/app/src/main/AndroidManifest.xml                                   # UPDATE — add `<queries>` element whitelisting `https:` scheme for url_launcher.launchUrl per FR-032.

# NO CHANGE: analysis_options.yaml, .github/workflows/, supabase/policies/, supabase/functions/, supabase/seed.sql, lib/shared/presentation/widgets/listing_display/ (consumed verbatim — zero edits).
```

**Structure Decision**: This feature lives across the Supabase backend tree (`supabase/migrations/` only — no functions, no policies, no docs edits in Phase 13) AND the Flutter app tree (`lib/features/home/` + `lib/features/listing_details/` are new feature folders; `lib/core/routing/`, `lib/core/di/`, `lib/core/errors/` are extended; `lib/shell/` is deleted; `lib/l10n/` gets ~25 new keys; `pubspec.yaml` + `pubspec.lock` + `android/app/src/main/AndroidManifest.xml` each get one Phase-13 delta). Phase 13 is the first phase to ship a **public anonymous-facing UI surface** AND the first phase to **delete** a prior phase's surface (Phase 1's `lib/shell/`). The five Q8=A shared widgets at `lib/shared/presentation/widgets/listing_display/` are CONSUMED verbatim per Phase 12 R-53 forward-state contract — zero edits.

## Phase Dependencies

> **User-mandated discipline**: Every "Phase B depends on Phase A" line below names the specific file path OR exported symbol that B consumes from A. Lines like "easier in sequence" or "uses concepts from" are FORBIDDEN. After writing this section, a self-audit (at the end of this section) counts undeclared-consumer lines; the audit must hit zero.

This Phase 13 implementation decomposes into **seven sub-phases (Sub-Phase A through Sub-Phase G)** that the `/wave` orchestrator can parallelize. Each sub-phase carries a **Touch fan** note listing every file the sub-phase modifies — orchestrators use these to pick merge order and pre-warn sub-agents about expected conflicts.

### Sub-Phase A — Index migration (Backend SQL)

**Scope**: Ship `supabase/migrations/<timestamp>_create_listings_indexes.sql` with four `CREATE INDEX IF NOT EXISTS` statements on `public.listings` per FR-001. Apply via Supabase MCP `apply_migration`. Verify via `EXPLAIN (ANALYZE, BUFFERS) SELECT ... LIMIT 20` per FR-002.

**Touch fan**: `supabase/migrations/<timestamp>_create_listings_indexes.sql` (CREATE only — no other file touched).

### Sub-Phase B — `url_launcher` dependency + AndroidManifest `<queries>` element

**Scope**: Add `url_launcher: ^6.x` to `pubspec.yaml`; run `flutter pub get` updating `pubspec.lock`; add `<queries>` element whitelisting `https:` scheme to `android/app/src/main/AndroidManifest.xml` per FR-032. The package's ONLY consumer in Phase 13 is Sub-Phase E's video-tap handler per FR-027.

**Touch fan**: `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml`.

### Sub-Phase C — ARB key delta + `app_strings.dart` extension (l10n)

**Scope**: Add ~25 new keys to `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` per FR-028 — HomePage chrome (6), Q1=A snackbars (2: `home_search_coming_soon`, `home_property_shortcut_coming_soon`), Q2=A snackbars (6: `contact_call_coming_soon`, `contact_whatsapp_coming_soon`, `contact_inquiry_coming_soon`, `action_favorite_coming_soon`, `action_share_coming_soon`, `action_report_coming_soon`), Q3=A reserved (2: `auth_required_please_sign_in`, `auth_required_sign_in_action`), ListingDetailsPage chrome (3), error/empty states (4), CTA labels (2 — the rest are reused from Phase 12's existing keys). Run `flutter gen-l10n` to regenerate `AppLocalizations`. Extend `lib/l10n/app_strings.dart` `_DebugAppLocalizations` subclass with concrete getters for the new abstract members per the Phase 11 DEFERRED.md forward-stated note.

**Touch fan**: `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_strings.dart`.

### Sub-Phase D — HomePage feature folder

**Scope**: Create `lib/features/home/{data,domain,presentation}/` with 11 new files per FR-012 / FR-013 / FR-014 / FR-015 / FR-016 / FR-017 / FR-018 / FR-019. Register the new datasource + repository + use case + bloc via `@injectable` annotations consumed by `build_runner`.

**Touch fan**: `lib/features/home/**` (11 new files — see Project Structure tree), `lib/core/di/injection.config.dart` (regenerated by `build_runner`).

### Sub-Phase E — ListingDetailsPage feature folder

**Scope**: Create `lib/features/listing_details/{data,domain,presentation}/` with 10 new files per FR-020 / FR-021 / FR-022 / FR-023 / FR-024 / FR-025 / FR-026 / FR-027. The page consumes Phase 12's five Q8=A shared widgets VERBATIM (no widget edits per SC-016). The Q4=D conditional back-button wiring lives in `listing_details_page.dart`'s AppBar IconButton onPressed handler + the `PopScope` body wrapper. The FR-027 video-tap launch is wired inside the `ListingGallery` widget's tap-handler hook — Phase 13 passes a callback into the widget; the widget itself is NOT modified (per Phase 12 Q8=A forward-state contract, consumers wrap behavior).

**Touch fan**: `lib/features/listing_details/**` (10 new files — see Project Structure tree), `lib/core/di/injection.config.dart` (regenerated), `lib/core/errors/failure.dart` (1 added subtype per R-68 if needed).

### Sub-Phase F — Routing rewire + `ShellHomePage` deletion

**Scope**: Update `lib/core/routing/app_router.dart`: swap `/` builder from `const ShellHomePage()` to `const HomePage()` per FR-008; add `/listings/:id` route per FR-010 with the path-parameter `id` parsed as a UUID; rename `AppRouteNames.shellHome` → `AppRouteNames.home` AND `AppRoutes.shellHome` → `AppRoutes.home` (interim alias `AppRoutes.shellHome = AppRoutes.home` retained for back-compat per R-69; full rename of every consumer is plan-time-decided). Delete `lib/shell/shell_home_page.dart` AND remove the `lib/shell/` directory per FR-009.

**Touch fan**: `lib/core/routing/app_router.dart`, `lib/shell/shell_home_page.dart` (DELETE), `lib/shell/` (DELETE DIR).

### Sub-Phase G — Manual verification (quickstart walks)

**Scope**: Execute `quickstart.md` against the running Supabase project + Infinix Note 8 + Pixel 8 Pro emulator. Verify all 35 SCs. Capture deferred items in `DEFERRED.md` if any emerge.

**Touch fan**: `specs/013-home-and-details/quickstart.md` (READ-ONLY checklist execution), `specs/013-home-and-details/DEFERRED.md` (CREATE if any deferrals emerge).

---

### Intra-Phase-13 sub-phase dependencies (with named consumers)

- **Sub-Phase F depends on Sub-Phase D** — `lib/core/routing/app_router.dart`'s `/` route builder returns `const HomePage()`, where `HomePage` is the class defined in `lib/features/home/presentation/pages/home_page.dart` (created by Sub-Phase D). The router file's `import 'package:alnujom/features/home/presentation/pages/home_page.dart';` line fails compilation until Sub-Phase D has merged.
- **Sub-Phase F depends on Sub-Phase E** — `lib/core/routing/app_router.dart`'s `/listings/:id` route builder returns `ListingDetailsPage(id: state.pathParameters['id']!)`, where `ListingDetailsPage` is the class defined in `lib/features/listing_details/presentation/pages/listing_details_page.dart` (created by Sub-Phase E). Same import-compile dependency.
- **Sub-Phase D depends on Sub-Phase C** — `lib/features/home/presentation/pages/home_page.dart` calls `AppLocalizations.of(context).homeSearchComingSoon` (per FR-013 Q1=A snackbar wiring), `AppLocalizations.of(context).homePropertyShortcutComingSoon(typeLabel)` (per FR-013 Q1=A parameterized snackbar), `AppLocalizations.of(context).latestListingsSectionHeader` (per FR-013 section header), `AppLocalizations.of(context).noListingsYetEmptyState` (per FR-019), `AppLocalizations.of(context).publishYourFirstListingCta` AND `AppLocalizations.of(context).signInToPublishCta` (per FR-019), `AppLocalizations.of(context).noMoreListingsSentinel` (per FR-016 infinite-scroll end), `AppLocalizations.of(context).couldNotLoadListingsErrorState` AND `AppLocalizations.of(context).retryButton` (per FR-014 error state). All getters generated by `flutter gen-l10n` from the ARB keys added by Sub-Phase C.
- **Sub-Phase E depends on Sub-Phase C** — `lib/features/listing_details/presentation/pages/listing_details_page.dart` calls `AppLocalizations.of(context).listingNotFoundState` AND `AppLocalizations.of(context).returnToHomeCta` (per FR-024), `AppLocalizations.of(context).couldNotLoadListingErrorState` (per FR-025). `lib/features/listing_details/presentation/widgets/contact_block.dart` calls `.contactCallComingSoon`, `.contactWhatsappComingSoon`, `.contactInquiryComingSoon` (per FR-021 Q2=A). `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart` calls `.actionFavoriteComingSoon`, `.actionShareComingSoon`, `.actionReportComingSoon` (per FR-021 Q2=A). All getters generated from ARB keys added by Sub-Phase C.
- **Sub-Phase E depends on Sub-Phase B** — `lib/features/listing_details/presentation/pages/listing_details_page.dart`'s video-tap callback (passed to `ListingGallery`) calls `url_launcher.launchUrl(Uri.parse(videoUrl), mode: LaunchMode.externalApplication)` per FR-027. The `url_launcher` package (added by Sub-Phase B to `pubspec.yaml`) MUST be resolvable at compile time. The AndroidManifest `<queries>` element (added by Sub-Phase B) is required for the Android 11+ scheme-visibility check to succeed at runtime; without it, the launch returns false.
- **Sub-Phase G depends on Sub-Phase A** — `quickstart.md` step "EXPLAIN check on home-feed SELECT" runs `EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM public.listings WHERE status='approved' ORDER BY published_at DESC, id DESC LIMIT 20` and asserts the output contains `Index Scan using idx_listings_status_published_at` (per FR-002 + SC-009). The index `idx_listings_status_published_at` is created by Sub-Phase A's migration.
- **Sub-Phase G depends on Sub-Phase D** — `quickstart.md` step "HomePage cold launch + first 20 cards" launches the app on the Infinix Note 8 and observes 20 cards rendered (per SC-001). The `HomePage` widget is created by Sub-Phase D.
- **Sub-Phase G depends on Sub-Phase E** — `quickstart.md` step "Listing details deep-link entry + back-button check" navigates to `/listings/<id>` and asserts the page renders with the back arrow following Q4=D conditional behavior (per SC-033). The `ListingDetailsPage` widget is created by Sub-Phase E.
- **Sub-Phase G depends on Sub-Phase F** — `quickstart.md` step "App opens on `/` to HomePage (NOT ShellHomePage)" launches the app from cold and asserts the rendered widget is `HomePage` per SC-011 + SC-010. The route binding is performed by Sub-Phase F.

### Cross-phase dependencies (Phase 13 → prior phases, with named consumers)

- **Phase 13 depends on Phase 12** — `lib/features/listing_details/presentation/pages/listing_details_page.dart` `import`s and composes five widgets from `lib/shared/presentation/widgets/listing_display/`: `ListingGallery` (from `listing_gallery.dart`), `ListingPriceBlock` (from `listing_price_block.dart`), `ListingLocationBlock` (from `listing_location_block.dart`), `ListingAmenitiesBlock` (from `listing_amenities_block.dart`), `ListingDescriptionBlock` (from `listing_description_block.dart`) — all five files shipped by Phase 12 per Q8=A. **Additional**: Phase 13's SC-002 anonymous-feed read predicate is the write-side outcome of Phase 12's `approve_listing` Edge Function (the only writer of `status='approved'` rows in the project); the home feed has no content until Phase 12 has merged AND at least one `approve_listing` call has succeeded.
- **Phase 13 depends on Phase 11** — `lib/features/home/data/datasources/supabase_home_feed_datasource.dart`'s embedded select for the main-image thumbnail reads from `public.listing_media` (table created by Phase 11 migration `0021_create_listing_media.sql`). `lib/features/listing_details/data/datasources/supabase_listing_details_datasource.dart`'s embedded select for the full media list reads from the same `public.listing_media` table. The `ListingGallery` widget (consumed via Phase 12's Q8=A) calls `Supabase.instance.client.storage.from('listing-images').getPublicUrl(storage_path)` against the `listing-images` bucket created by Phase 11's `supabase/storage/buckets.sql`. Phase 11's anonymous-Storage RLS gates the actual byte download — Phase 13's SC-008 (deep-link to non-approved listing returns 404/403) is verified end-to-end against Phase 11's policy.
- **Phase 13 depends on Phase 10** — `lib/features/home/data/datasources/supabase_home_feed_datasource.dart`'s SELECT FROM `public.listings` reads the table created by Phase 10 migration `0016_create_listings.sql`. Embedded selects read `public.listing_prices` (Phase 10 `0018_create_listing_prices.sql`) for the primary price. The Dart entity `Listing` (defined at `lib/features/listings/domain/entities/listing.dart` by Phase 10) is reused by Phase 13's `HomeListingCard` projection AND by `ListingDetailsAggregate`. The Dart entities `ListingDetails` + `ListingPrice` (Phase 10 `lib/features/listings/domain/entities/`) are composed into `ListingDetailsAggregate` (Phase 13). Phase 10's public-read RLS on `public.listings` (the `status='approved' AND publish-window-open` predicate) is the SOLE filter for Phase 13's home-feed + details queries per FR-018 + SC-008.
- **Phase 13 depends on Phase 9** — `lib/features/home/presentation/widgets/home_listing_card.dart`'s price rendering calls `MoneyFormatter.format(amount, currency, locale)` from `lib/shared/domain/value_objects/money.dart` (defined by Phase 9). The Phase 12 Q8=A `ListingPriceBlock` widget (consumed by Phase 13's ListingDetailsPage) also calls `MoneyFormatter.format(...)`. Cross-currency conversion reads the latest active row from `public.exchange_rates` (table created by Phase 9 `0015_create_exchange_rates.sql`) when the user's `display_currency` differs from the listing's stored primary currency.
- **Phase 13 depends on Phase 8** — `lib/features/home/presentation/widgets/home_listing_card.dart`'s location rendering shows `<governorate.nameLocalized(locale)> / <city.nameLocalized(locale)>` using the entity methods on `Governorate` + `City` (defined at `lib/features/locations/domain/entities/governorate.dart` AND `city.dart` by Phase 8). The Phase 12 Q8=A `ListingLocationBlock` widget (consumed by Phase 13's ListingDetailsPage) also reads `Governorate` / `City` / `Area` entities. The embedded select in the home-feed query reads `public.governorates` + `public.cities` (tables created by Phase 8 `0011_create_governorates.sql` + `0012_create_cities.sql`); the details-page query additionally reads `public.areas` (Phase 8 `0013_create_areas.sql`).
- **Phase 13 depends on Phase 5** — `lib/features/home/presentation/pages/home_page.dart`'s AppBar sign-in icon AND the empty-state "Sign in to publish" CTA route to the Phase 5 login route (the `AppRoutes.login` constant defined at `lib/core/routing/app_router.dart` by Phase 5). `lib/features/listing_details/presentation/bloc/listing_details_bloc.dart`'s `AuthStateChanged` event listener subscribes to `AuthBloc` defined at `lib/features/auth/presentation/bloc/auth_bloc.dart` by Phase 5 — so the page re-renders auth-dependent CTAs without a manual refresh per FR-022. The "Sign in to publish" path follows Phase 5's standard sign-in flow without modification.
- **Phase 13 depends on Phase 3** — All new user-visible strings flow through `AppLocalizations` generated from `lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb` by Phase 3's `flutter gen-l10n` toolchain. Phase 3's localization lint guard at `analysis_options.yaml` enforces zero hardcoded literals in feature code per SC-014. Time-since-publish on the home card uses `intl` package's `RelativeDateFormat` (added as a Phase 3 dependency) — Phase 13 is the FIRST consumer of `RelativeDateFormat` in the project per R-67.
- **Phase 13 depends on Phase 2** — Every new widget reads from `Theme.of(context)` + the Phase 2 design-token module at `lib/core/theme/` (`colors.dart`, `typography.dart`, `spacing.dart`, `radii.dart`, `elevation.dart`). The hero-search-bar uses Phase 2's `surfaceVariant` color token; property-type chips use `secondaryContainer`; the home-feed card uses `surfaceContainer`; error states use `errorContainer` / `onErrorContainer`. The Phase 2 `ListingCard` reusable widget at `lib/shared/presentation/widgets/listing_card.dart` (if it exists per the Phase 2 component-library contract) MAY be the base for Phase 13's `_HomeListingCard` — plan-time R-65 decides whether to reuse or to ship a Phase-13-specific card.
- **Phase 13 depends on Phase 1** — `lib/core/routing/app_router.dart` is Phase 1's file (updated by Sub-Phase F); Phase 13 swaps the `/` builder + adds one route. `lib/shell/shell_home_page.dart` is Phase 1's surface (deleted by Sub-Phase F). The `cached_network_image` package is a Phase 1 dependency declared in `pubspec.yaml`; Phase 13 is the FIRST public-surface consumer (via the Phase 12 Q8=A `ListingGallery` widget's `CachedNetworkImage(...)` call). The `go_router` package is a Phase 1 dependency; Phase 13 adds one route via the existing `GoRouter` instance built by Phase 1's `lib/core/routing/app_router.dart`. Phase 1's `lib/core/network/supabase_client.dart` wrapper is consumed unchanged — the new datasources call `Supabase.instance.client.from(...)` through this wrapper. Phase 1's `Result<T>` / `Failure` types in `lib/core/errors/` are consumed by the new use cases; one new `ListingNotFoundFailure` subtype is added per R-68.

### Self-audit of Phase Dependencies

> Per the user-mandated discipline at the top of this section, I counted every "depends on" line above and verified each names a specific file path OR exported symbol. A leaner graph produces a wider parallel execution wave AND saves real wall-clock time.

| Dependency line | Named consumer? | Notes |
|---|---|---|
| Sub-Phase F → Sub-Phase D | ✅ Named — `app_router.dart` imports `HomePage` class from `home_page.dart`. | Hard compile-time dep. |
| Sub-Phase F → Sub-Phase E | ✅ Named — `app_router.dart` imports `ListingDetailsPage` class from `listing_details_page.dart`. | Hard compile-time dep. |
| Sub-Phase D → Sub-Phase C | ✅ Named — `home_page.dart` calls 8 specific `AppLocalizations` getters generated from ARB keys (`homeSearchComingSoon`, `homePropertyShortcutComingSoon`, `latestListingsSectionHeader`, `noListingsYetEmptyState`, `publishYourFirstListingCta`, `signInToPublishCta`, `noMoreListingsSentinel`, `couldNotLoadListingsErrorState`, `retryButton`). | Hard compile-time dep (generated getter must exist). |
| Sub-Phase E → Sub-Phase C | ✅ Named — `listing_details_page.dart` + `contact_block.dart` + `per_listing_action_block.dart` call 9 specific `AppLocalizations` getters. | Hard compile-time dep. |
| Sub-Phase E → Sub-Phase B | ✅ Named — `listing_details_page.dart`'s video-tap callback calls `url_launcher.launchUrl(...)`; `url_launcher` package added by Sub-Phase B. | Hard compile-time dep (package import). |
| Sub-Phase G → Sub-Phase A | ✅ Named — `quickstart.md` EXPLAIN check asserts `idx_listings_status_published_at` is used. | Hard runtime dep (index must exist in DB). |
| Sub-Phase G → Sub-Phase D | ✅ Named — `quickstart.md` cold-launch step asserts `HomePage` widget renders. | Hard runtime dep. |
| Sub-Phase G → Sub-Phase E | ✅ Named — `quickstart.md` deep-link step asserts `ListingDetailsPage` renders with Q4=D back-arrow. | Hard runtime dep. |
| Sub-Phase G → Sub-Phase F | ✅ Named — `quickstart.md` cold-launch step asserts `/` routes to `HomePage` (not `ShellHomePage`). | Hard runtime dep. |
| Phase 13 → Phase 12 | ✅ Named — 5 specific widget classes imported from 5 specific files under `lib/shared/presentation/widgets/listing_display/`. Plus the `approve_listing` Edge Function's `status='approved'` writes as the home-feed data source. | Hard compile-time + runtime dep. |
| Phase 13 → Phase 11 | ✅ Named — `public.listing_media` table + `listing-images` Storage bucket + the `getPublicUrl()` call against that bucket + Phase 11's anonymous-Storage RLS policy. | Hard runtime dep (table + bucket + policy must exist). |
| Phase 13 → Phase 10 | ✅ Named — `public.listings` + `public.listing_prices` + `public.listing_details` tables; `Listing` + `ListingDetails` + `ListingPrice` Dart entities at specific paths; Phase 10's public-read RLS policy on `public.listings`. | Hard compile-time + runtime dep. |
| Phase 13 → Phase 9 | ✅ Named — `MoneyFormatter` value object at `lib/shared/domain/value_objects/money.dart`; `public.exchange_rates` table. | Hard compile-time + runtime dep. |
| Phase 13 → Phase 8 | ✅ Named — `Governorate` + `City` + `Area` entities at specific paths; `public.governorates` + `public.cities` + `public.areas` tables. | Hard compile-time + runtime dep. |
| Phase 13 → Phase 5 | ✅ Named — `AppRoutes.login` constant; `AuthBloc` at `lib/features/auth/presentation/bloc/auth_bloc.dart`. | Hard compile-time dep. |
| Phase 13 → Phase 3 | ✅ Named — `AppLocalizations` class generated from ARB files; `intl` `RelativeDateFormat` API. | Hard compile-time dep. |
| Phase 13 → Phase 2 | ✅ Named — Phase 2 design-token module at `lib/core/theme/` (5 files: `colors.dart`, `typography.dart`, `spacing.dart`, `radii.dart`, `elevation.dart`); specific color tokens (`surfaceVariant`, `secondaryContainer`, `surfaceContainer`, `errorContainer`, `onErrorContainer`). The optional `ListingCard` reuse decision is R-65. | Hard compile-time dep. |
| Phase 13 → Phase 1 | ✅ Named — `app_router.dart` file + `GoRouter` instance (Phase 1 surface to extend); `ShellHomePage` class + `lib/shell/` directory (Phase 1 surface to delete); `cached_network_image` + `go_router` packages in `pubspec.yaml`; `supabase_client.dart` wrapper; `Result<T>` + `Failure` types. | Hard compile-time dep. |

**Audit result**: **17 of 17 declared dependencies name specific consumers (file paths AND/OR exported symbols).** Zero unnamed deps. Zero "easier in sequence" or "uses concepts from" lines.

**Parallel execution wave shape** (derived from the dependency graph):

- **Wave 1 (no deps; can run in parallel)**: Sub-Phase A, Sub-Phase B, Sub-Phase C.
- **Wave 2 (depends on Wave 1)**: Sub-Phase D (depends on C), Sub-Phase E (depends on B + C). Both can run in parallel within Wave 2 since they touch disjoint feature folders + share only the `injection.config.dart` codegen surface (which `build_runner` regenerates idempotently).
- **Wave 3 (depends on Wave 2)**: Sub-Phase F (depends on D + E).
- **Wave 4 (depends on Waves 1+2+3)**: Sub-Phase G (depends on A + D + E + F).

Total wall-clock waves: **4** (vs. the over-conservative 7-wave serial execution that would result if every dep were declared without symbols). The `/wave` orchestrator picks merge order in this shape.

## Complexity Tracking

> No Constitution Check violations. Section intentionally empty.
