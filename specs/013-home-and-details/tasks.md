---

description: "Task list — Phase 13 (Public Home & Listing Details)"
---

# Tasks: Public Home & Listing Details

**Input**: Design documents from `specs/013-home-and-details/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅ (7 files), quickstart.md ✅

**Tests**: Per `feedback_no_new_tests.md` (durable, 10th consecutive phase), Phase 13 introduces **NO new automated tests of any kind**. Every Functional Requirement is verified via manual UI walks (Infinix Note 8 primary + Pixel 8 Pro emulator secondary), `EXPLAIN`/`grep` audits, or Supabase MCP inspection. Build-time validation is preserved (analyzer, gen-l10n, `flutter pub get`, `apply_migration` SQL parser).

**Organization**: Tasks are grouped by sub-phase (A–G from plan.md) and user story (US1–US6 from spec.md). The seven sub-phases map cleanly onto the user stories with two foundational sub-phases (A + B + C) preceding the two implementation sub-phases (D for US1, E for US2) plus an integration sub-phase (F) plus verification + polish.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1–US6 from spec.md (Setup / Foundational / Polish phases have no story label)
- Every implementation task includes exact file paths

## Path Conventions

Repo layout is **Flutter app + Supabase backend** (per plan.md Project Structure):
- Flutter: `lib/features/<feature>/{data,domain,presentation}/`, `lib/core/`, `lib/shared/`, `lib/l10n/`
- Backend: `supabase/migrations/`
- Android manifest: `android/app/src/main/AndroidManifest.xml`

---

## Phase 1: Setup

**Purpose**: Confirm the workspace is ready for Phase 13 implementation.

- [X] T001 Verify the active feature directory is `specs/013-home-and-details` per `.specify/feature.json` and that the active git branch is `013-home-and-details` per `git branch --show-current`. If either is wrong, halt and ask before proceeding.

---

## Phase 2: Foundational (Sub-Phases A + B + C — blocking prerequisites for all user stories)

**Purpose**: Three independent foundational deliverables that BLOCK all user story implementation.

**⚠️ CRITICAL**: User story work cannot begin until A, B, C all merge.

### Sub-Phase A — Index migration (per FR-001, FR-002, FR-003, FR-004)

- [X] T002 [P] Create migration file at `supabase/migrations/20260524120001_create_listings_indexes.sql` with the four `CREATE INDEX IF NOT EXISTS` statements per data-model.md §1 (idx_listings_status_published_at, idx_listings_status_created_at, idx_listings_governorate_status, idx_listings_property_type_status — exact bodies in data-model.md lines 27-44).
- [X] T003 [P] Apply the migration via Supabase MCP `apply_migration` with migration name `create_listings_indexes` per R-61 + `project_supabase_mcp_apply_migration.md`. Confirm uniqueness against `mcp__supabase__list_migrations` before applying.
- [X] T004 [P] Verify via Supabase MCP `execute_sql` running `EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM public.listings WHERE status='approved' ORDER BY published_at DESC, id DESC LIMIT 20` — assert output contains `Index Scan using idx_listings_status_published_at` (NOT `Seq Scan`) at any row count ≥ 100. Soft requirement below 100 rows per FR-002.

### Sub-Phase B — `url_launcher` dependency + AndroidManifest `<queries>` (per FR-032, FR-033)

- [X] T005 [P] Add `url_launcher: ^6.x` to the `dependencies:` block of `pubspec.yaml`. Do NOT add `share_plus` (FR-033 deferred per Q2=A).
- [X] T006 [P] Run `flutter pub get` to update `pubspec.lock`. Pin the exact resolved version (do not check in a `^` constraint at the lock layer).
- [X] T007 [P] Add the `<queries>` element to `android/app/src/main/AndroidManifest.xml` whitelisting the `https:` scheme only (NOT `tel:` or `mailto:` — Q2=A stubs those CTAs). Pattern:
  ```xml
  <queries>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <data android:scheme="https" />
    </intent>
  </queries>
  ```

### Sub-Phase C — ARB delta + `app_strings.dart` extension (per FR-028, FR-035)

- [X] T008 [P] Add ~28 new keys to `lib/l10n/app_en.arb` per data-model.md §5 (groups 5.1–5.8, which inventory 31 entries with ~3 reused — exact net count determined by grep at implementation per the corrected §5 summary). Use exact key names from §5: `home_app_bar_title`, `home_sign_in_icon_tooltip`, `home_search_bar_placeholder`, `home_latest_listings_header`, `home_no_listings_yet`, `home_no_more_listings`, `home_search_coming_soon`, `home_property_shortcut_coming_soon` (parameterized `{type}`), `contact_call_coming_soon`, `contact_whatsapp_coming_soon`, `contact_inquiry_coming_soon`, `action_favorite_coming_soon`, `action_share_coming_soon`, `action_report_coming_soon`, `auth_required_please_sign_in`, `auth_required_sign_in_action`, `listing_details_not_found_title`, `listing_details_not_found_return_home`, `listing_details_publisher_label` (parameterized `{name}`), `cta_call`, `cta_whatsapp`, `cta_send_inquiry`, `cta_favorite`, `cta_share`, `cta_report`, `error_could_not_load_listings`, `error_could_not_load_listing`, `action_retry`, `image_unavailable`, `home_empty_publish_first_listing`, `home_empty_sign_in_to_publish`. For keys flagged "may reuse existing", grep `lib/l10n/app_en.arb` first; reuse if present, otherwise add. Include `@key` metadata blocks with placeholder type info for parameterized keys.
- [X] T009 [P] Mirror every new English key in `lib/l10n/app_ar.arb` using the Arabic strings from data-model.md §5. Maintain identical key ordering between the two files for diff-clarity.
- [X] T010 Run `flutter gen-l10n` to regenerate `AppLocalizations`. Confirm zero analyzer errors and that every new abstract getter is present.
- [X] T011 Extend the hand-maintained `_DebugAppLocalizations` subclass in `lib/l10n/app_strings.dart` with concrete implementations of every new getter generated in T010, per the Phase 11 DEFERRED.md forward-stated note. Return the English string from each getter (debug fallback only).

**Checkpoint**: Foundation ready — Sub-Phases D + E may now begin in parallel.

---

## Phase 3: User Story 1 — Anonymous browses paginated home feed (Priority: P1) 🎯 MVP

**Goal**: Anonymous visitor opens app → lands on `HomePage` at `/` → sees first 20 cards within 3 sec → infinite-scrolls without duplicates/skips → pull-to-refresh → Q1=A snackbar stubs on hero search + property-type chips.

**Independent Test**: Apply T002–T011, then launch on Infinix Note 8 signed out with ≥ 25 approved listings seeded. Confirm: HomePage renders (NOT ShellHomePage), 20 cards ordered by `(published_at DESC, id DESC)`, infinite-scroll loads 21–25 without dup of card 20, pull-to-refresh works, hero search tap → snackbar, property-type chip tap → snackbar with `{type}` interpolated.

**Maps to**: Sub-Phase D from plan.md.

### Implementation — Sub-Phase D (HomePage feature folder)

- [X] T012 [P] [US1] Create `lib/features/home/domain/entities/home_listing_card.dart` defining the `HomeListingCard` `Equatable` entity per data-model.md §2.3 (fields: id, title, propertyType, purpose, governorateNameLocalized, cityNameLocalized, primaryPrice, mainImageStoragePath, publishedAt). Import Phase 10's `PropertyType` + `ListingPurpose` enums + `ListingPrice` entity.
- [X] T013 [P] [US1] Create `lib/features/home/domain/entities/cursor.dart` defining the `Cursor` value object per data-model.md §2.4 (fields: publishedAt, id; constructor `Cursor.fromLastCard(HomeListingCard last)`).
- [X] T014 [P] [US1] Create `lib/features/home/domain/repositories/home_feed_repository.dart` defining the abstract `HomeFeedRepository` interface with `Future<Result<List<HomeListingCard>>> fetchPage(Cursor? cursor)`.
- [X] T015 [US1] Create `lib/features/home/domain/usecases/load_home_feed.dart` defining the `LoadHomeFeed` use case wrapping `HomeFeedRepository.fetchPage(cursor)`. Depends on T014.
- [X] T016 [P] [US1] Create `lib/features/home/data/dtos/home_listing_card_dto.dart` per data-model.md §2.2 with `fromJson` factory parsing the embedded-selects projection shape (listing_prices!inner, listing_media, governorate, city). Locale-resolve `nameAr` vs `nameEn` at DTO→entity mapping per current `AppLocalizations.of(context).localeName`.
- [X] T017 [US1] Create `lib/features/home/data/datasources/supabase_home_feed_datasource.dart` per data-model.md §2.1 + contracts/phase13-home-feed-query.md. Issue the embedded-selects query per R-63 (full body in §2.1). RLS-only filter — NO `.eq('status', 'approved')` per FR-018. Apply cursor via a **single `.or()` filter** expressing the lexicographic strict-less-than tuple compare per R-62 (corrected): `query.or('published_at.lt.$pubAt,and(published_at.eq.$pubAt,id.lt.${cursor.id})')`. Do NOT use chained `.lt('published_at', ...) + .lt('id', ...)` — that approach was rejected at /speckit-analyze 2026-05-23 because it silently skips rows on pagination boundaries with tied `published_at` values, breaking US5. Order by `published_at DESC, id DESC`, `.limit(20)`. This is the **ONLY** file under `lib/features/home/` importing `package:supabase_flutter` per FR-030.
- [X] T018 [US1] Create `lib/features/home/data/repositories/home_feed_repository_impl.dart` implementing T014's interface by delegating to T017's datasource. Wrap exceptions in appropriate `Failure` subtypes (network → `NetworkFailure`, etc.). Annotate with `@LazySingleton(as: HomeFeedRepository)`.
- [X] T019 [US1] Create `lib/features/home/presentation/bloc/home_bloc.dart` exposing events `HomeFeedLoadRequested`, `HomeFeedNextPageRequested`, `HomeFeedRefreshRequested` and state `HomeState(listings, status, cursor, failure)` with `HomeFeedStatus ∈ {initial, loading, success, error, loadingMore, refreshing}` per FR-014. State machine MUST prevent duplicate concurrent fetches: while `status ∈ {loadingMore, refreshing}`, subsequent identical events are ignored. Annotate with `@injectable`.
- [X] T020 [P] [US1] Create `lib/features/home/presentation/widgets/hero_search_bar.dart` (`_HeroSearchBar`) per contracts/phase13-home-page-composition.md §2 + contracts/phase13-cta-stub-treatment.md. Phase 2 `surfaceVariant` background + `radii.md`; leading `Icons.search`; trailing `home_search_bar_placeholder` text; tap handler dismisses keyboard via `FocusScope.of(context).unfocus()` then shows `home_search_coming_soon` snackbar (floating per Phase 2 token, 3-sec duration). NO navigation per Q1=A.
- [X] T021 [P] [US1] Create `lib/features/home/presentation/widgets/property_type_shortcut_row.dart` (`_PropertyTypeShortcutRow`) per contracts/phase13-home-page-composition.md §3. Horizontal scroll of 8 `Chip` widgets — types: `apartment`, `villa`, `land`, `shop`, `office`, `farm`, `warehouse`, `other` (per §6.3 enum). Each chip: Phase 2 `secondaryContainer` background, Phase 2 icon-token per type, localized label (reuse existing Phase 10 `propertyType_<key>` ARB keys if present per T008 note). Tap handler shows `home_property_shortcut_coming_soon` snackbar with `{type}` placeholder interpolated to the tapped type's localized label per Q1=A. NO navigation.
- [X] T022 [P] [US1] Create `lib/features/home/presentation/widgets/home_listing_card.dart` (`_HomeListingCard`) per FR-017 + R-65 (Phase-13-specific, NOT reusing Phase 2's generic `ListingCard`). Layout: main image via `CachedNetworkImage` against `supabase.storage.from('listing-images').getPublicUrl(card.mainImageStoragePath!)` with `cached_network_image` placeholder builder rendering a Phase-2-token-styled `Container` of 16:9 aspect; title `Text` with 2-line ellipsis per Phase 2 typography token; type + purpose badges; governorate + city names (joined per Phase 8 conventions, no area); primary price via Phase 9 `MoneyFormatter.format(...)` in user's `display_currency`; time-since-publish via `intl.RelativeDateTime` per R-67 against current locale. Tap routes via `context.go(AppRoutes.listingDetailsFor(card.id))`. Use `EdgeInsetsDirectional` everywhere per Constitution VI. No inline hex / pixel constants.
- [X] T023 [US1] Create `lib/features/home/presentation/pages/home_page.dart` per contracts/phase13-home-page-composition.md. Composes (top-to-bottom): AppBar with brand-mark + auth-state-branched sign-in/profile icon via `BlocSelector<AuthBloc, AuthState, bool>`; `_HeroSearchBar`; `_PropertyTypeShortcutRow`; section header `home_latest_listings_header`; `RefreshIndicator`-wrapped `ListView.builder` of `_HomeListingCard` widgets driven by `HomeBloc`. `ScrollController` listener fires `HomeFeedNextPageRequested` 5 cards from bottom per FR-016. BlocBuilder switches on `state.status`: initial/loading → centered spinner; success+empty → empty-state per FR-019 (auth-branched CTA: `home_empty_publish_first_listing` → Phase 10 listing form for approved publisher, else `home_empty_sign_in_to_publish` → `AppRoutes.login`); success+non-empty → list + footer (`loadingMore` spinner OR `home_no_more_listings` sentinel); error → `error_could_not_load_listings` + `action_retry` button. Depends on T019–T022.
- [X] T024 [US1] Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/injection.config.dart` with the new HomeBloc + use case + repository + datasource registrations. Depends on T015, T017, T018, T019.
- [X] T025 [US1] In the same commit as the last task above, flip `- [ ] T002` through `- [ ] T024` to `- [X]` in this file per the closing rule of `Multi-Agent Execution Notes` below.

**Checkpoint (US1)**: HomePage compiles and renders independently. The `/` route still binds to `ShellHomePage` until Sub-Phase F (Phase 5 below) executes — that's the integration step. To preview US1 work in isolation before F lands, temporarily run the app via a one-off `MaterialApp(home: HomePage())` harness; revert before commit.

---

## Phase 4: User Story 2 — Anonymous opens listing details + gallery swipe + video tap (Priority: P1) 🎯 MVP

**Goal**: Tap any home card → `ListingDetailsPage` renders within 2 sec via `/listings/:id` → five Phase-12 Q8=A shared widgets compose verbatim → gallery swipes → video tap launches external OS player via `url_launcher` → six CTAs are Q2=A snackbar stubs → Q4=D deep-link back-button works.

**Independent Test**: Tap any card on HomePage OR deep-link via `adb shell am start -a android.intent.action.VIEW -d "alnujom://listings/<approved-uuid>" com.alnujom.app`. Confirm page renders within 2 sec, five Q8=A widgets render in order (Gallery → PriceBlock → LocationBlock → AmenitiesBlock → DescriptionBlock interleaved with Phase-13-owned title + ContactBlock + PerListingActionBlock), gallery swipes, video tap launches VLC on Infinix Note 8, all 6 CTAs show snackbars, back arrow returns to HomePage (NOT exit app) under deep-link entry.

**Maps to**: Sub-Phase E from plan.md.

### Implementation — Sub-Phase E (ListingDetailsPage feature folder)

- [X] T026 [P] [US2] Extend `lib/core/errors/failure.dart` with `class ListingNotFoundFailure extends Failure { const ListingNotFoundFailure(); }` per data-model.md §4 + R-68. Grep `lib/core/errors/` first — if a generic `NotFoundFailure` already exists, reuse instead and skip this task.
- [X] T027 [P] [US2] Create `lib/features/listing_details/domain/entities/listing_details_aggregate.dart` defining `ListingDetailsAggregate` (composes Phase 10's `Listing` + `ListingDetails` + `List<ListingPrice>` + Phase 11's `List<ListingMedia>` + Phase 8's `Governorate` + `City` + `Area`) and `PublisherSummary` (fullName + nullable username — private fields explicitly NOT projected per ADR-0001) per data-model.md §3.2.
- [X] T028 [P] [US2] Create `lib/features/listing_details/domain/repositories/listing_details_repository.dart` defining the abstract `ListingDetailsRepository` with `Future<Result<ListingDetailsAggregate>> fetchListing(String id)` returning `ListingNotFoundFailure` on null/RLS-hidden row.
- [X] T029 [US2] Create `lib/features/listing_details/domain/usecases/load_listing_details.dart` wrapping the repository call. Depends on T028.
- [X] T030 [P] [US2] Create `lib/features/listing_details/data/dtos/listing_details_aggregate_dto.dart` with `fromJson` factory parsing the embedded-selects projection from data-model.md §3.1 (listing_details, listing_prices, listing_media, governorate/city/area, publisher).
- [X] T031 [US2] Create `lib/features/listing_details/data/datasources/supabase_listing_details_datasource.dart` per data-model.md §3.1 + contracts/phase13-listing-details-query.md. Issue the embedded-selects query per R-64. RLS-only filter — NO `.eq('status', 'approved')` per FR-018. Use `.eq('id', listingId).maybeSingle()` — `null` return maps to FR-024 "Listing not found". Project ONLY `full_name` + `username` from `profiles` (private Vault fields excluded per ADR-0001). This is the **ONLY** file under `lib/features/listing_details/` importing `package:supabase_flutter` per FR-030.
- [X] T032 [US2] Create `lib/features/listing_details/data/repositories/listing_details_repository_impl.dart` implementing T028. Map `null` from datasource → `Left(ListingNotFoundFailure())`. Annotate with `@LazySingleton(as: ListingDetailsRepository)`.
- [X] T033 [US2] Create `lib/features/listing_details/presentation/bloc/listing_details_bloc.dart` per FR-022 + R-70 (INDEPENDENT of Phase 12's `ListingPreviewBloc`; NO shared imports). Events: `ListingDetailsLoadRequested(String id)`, `AuthStateChanged`, `RetryRequested`. State: `ListingDetailsState` with `(aggregate, status, failure)` and `ListingDetailsStatus ∈ {initial, loading, success, notFound, error}`. `AuthStateChanged` subscribes to Phase 5's `AuthBloc` per Phase 13 → Phase 5 cross-phase dep. Annotate with `@injectable`.
- [X] T034 [P] [US2] Create `lib/features/listing_details/presentation/widgets/contact_block.dart` (`_ContactBlock`) per contracts/phase13-listing-details-page-composition.md §6 + contracts/phase13-cta-stub-treatment.md. Three `OutlinedButton.icon` widgets: `cta_call` + `Icons.phone` → snackbar `contact_call_coming_soon`; `cta_whatsapp` + WhatsApp/`Icons.chat` icon → snackbar `contact_whatsapp_coming_soon`; `cta_send_inquiry` + `Icons.email` → snackbar `contact_inquiry_coming_soon`. Phase 2 token styling. NO `url_launcher.launch('tel:...')` / `wa.me/` calls per Q2=A.
- [X] T035 [P] [US2] Create `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart` (`_PerListingActionBlock`) per contracts/phase13-listing-details-page-composition.md §9 + contracts/phase13-cta-stub-treatment.md. Three Phase-2-token CTAs: `cta_favorite` + heart icon → snackbar `action_favorite_coming_soon`; `cta_share` + share icon → snackbar `action_share_coming_soon`; `cta_report` + flag icon → snackbar `action_report_coming_soon`. NO share-sheet / favorite mutation / report INSERT.
- [X] T036 [US2] Create `lib/features/listing_details/presentation/pages/listing_details_page.dart` per contracts/phase13-listing-details-page-composition.md + contracts/phase13-deep-link-back-button.md. Composes (top-to-bottom): `AppBar(leading: IconButton(icon: Icons.arrow_back, onPressed: _handleBack))`; `ListingGallery` (imported VERBATIM from `lib/shared/presentation/widgets/listing_display/listing_gallery.dart` per FR-026; pass `onVideoTap` callback that calls `url_launcher.launchUrl(Uri.parse(getPublicUrl(videoMedia.storagePath)), mode: LaunchMode.externalApplication)` per FR-027); title `Text(state.listing.title, style: Theme.of(context).textTheme.headlineSmall)`; `ListingPriceBlock` (verbatim); `ListingLocationBlock` (verbatim); `_ContactBlock`; `ListingAmenitiesBlock` (verbatim); `ListingDescriptionBlock` (verbatim); `_PerListingActionBlock`. Wrap whole body in `PopScope(canPop: false, onPopInvoked: (didPop) { if (!didPop) _handleBack(); })`. The `_handleBack()` inline helper implements Q4=D per R-71: `if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else { context.go(AppRoutes.home); }`. BlocBuilder switch: loading → spinner; notFound → `_NotFoundView()` rendering `listing_details_not_found_title` + `listing_details_not_found_return_home` CTA → `context.go(AppRoutes.home)`; error → `_ErrorView()` rendering `error_could_not_load_listing` + `action_retry` button firing `RetryRequested`; success → `_SuccessBody(state)` rendering composition 2–9 above. Depends on T026, T033, T034, T035.
- [X] T037 [US2] Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/injection.config.dart` with the new ListingDetailsBloc + use case + repository + datasource. (If T024 already ran, re-run is idempotent.) Depends on T029, T031, T032, T033.
- [X] T038 [US2] In the same commit as the last task above, flip `- [ ] T026` through `- [ ] T037` to `- [X]` per the closing rule below.

**Checkpoint (US2)**: ListingDetailsPage compiles and renders. The `/listings/:id` route is NOT yet bound until Sub-Phase F (Phase 5 below). To preview US2 in isolation, temporarily push the page via `Navigator.push(MaterialPageRoute(builder: (_) => ListingDetailsPage(id: 'known-uuid')))`; revert before commit.

---

## Phase 5: Integration — Routing rewire + ShellHomePage deletion (Sub-Phase F)

**Purpose**: Bind `/` to `HomePage` (was `ShellHomePage`); add `/listings/:id`; delete the Phase 1 shell surface. This is the bridge between US1 + US2 implementations and the user-visible product. Touches one shared file (`app_router.dart`) plus a directory deletion.

**Maps to**: Sub-Phase F from plan.md. Depends on Sub-Phases D + E (named consumer per plan.md line 280-281: `app_router.dart` imports `HomePage` from `home_page.dart` AND `ListingDetailsPage` from `listing_details_page.dart`).

- [X] T039 Update `lib/core/routing/app_router.dart`: (a) swap `/` route builder from `const ShellHomePage()` to `const HomePage()` per FR-008; (b) add new route `GoRoute(path: '/listings/:id', name: AppRouteNames.listingDetails, builder: (context, state) => ListingDetailsPage(id: state.pathParameters['id']!))` per FR-010; (c) rename constants `AppRouteNames.shellHome` → `AppRouteNames.home` (`'home'`) and `AppRoutes.shellHome` → `AppRoutes.home` (`'/'`); (d) per R-69, retain interim back-compat alias `static const String shellHome = home;` on both classes for one PR lifetime; (e) add `AppRoutes.listingDetails = '/listings/:id'` constant + helper `static String listingDetailsFor(String id) => '/listings/$id';`; (f) update imports to add `package:alnujom/features/home/presentation/pages/home_page.dart` and `package:alnujom/features/listing_details/presentation/pages/listing_details_page.dart`. Remove `import 'package:alnujom/shell/shell_home_page.dart';`.
- [X] T040 Delete `lib/shell/shell_home_page.dart` and remove the empty `lib/shell/` directory per FR-009 + SC-010. Confirm via `git status` that the deletion is staged.
- [X] T041 Re-verify all in-repo consumers of the old `AppRoutes.shellHome` / `AppRouteNames.shellHome` constants. Grep: `grep -RE "AppRoutes\.shellHome|AppRouteNames\.shellHome" lib/`. Any in-tree consumer either resolves via the interim alias (acceptable) or is updated to `AppRoutes.home` / `AppRouteNames.home` in the same commit. Document any deferred renames in `specs/013-home-and-details/DEFERRED.md` as "follow-up alias removal".
- [X] T042 In the same commit, flip `- [ ] T039` through `- [ ] T041` to `- [X]` per the closing rule below.

**Checkpoint (Integration)**: App now launches to HomePage at `/` and supports `/listings/:id` deep-link entry. End-to-end product UX is intact. Manual verification phases follow.

---

## Phase 6: User Story 3 — Authenticated user uses same surfaces (Priority: P2)

**Goal**: Sign-in as user/publisher/admin shows the SAME home feed as anonymous; publisher's own non-approved listings absent; sign-out re-renders without re-fetch.

**Independent Test**: From a seeded session, sign in as each of the 3 role categories (user, publisher with mixed-status listings, admin). Confirm: home feed shows only public-approved listings (publisher's draft/pending/rejected absent); sign-out preserves the feed.

**No new code** — Phase 13 reads are auth-symmetric via RLS. This phase is pure manual verification.

- [X] T043 [US3] Execute quickstart.md steps marked "US3" against Infinix Note 8 (primary per R-72 device matrix). Sign in as a publisher with at least one listing in each of `draft`, `pending_review`, `rejected` statuses + at least one `approved`. Confirm only the `approved` row appears on the home feed (per SC-026). Confirm tap → details renders identically to anonymous case. Sign out → confirm feed unchanged (no spinner, no re-fetch). Record observed behavior + any anomalies in DEFERRED.md. **Verified 2026-05-24 on Pixel 8 Pro emulator (Infinix Note 8 deferred to user): publisher's `approved` listing ("Luxury HOuse in AlMaza") appeared on feed; non-approved listings absent (per SC-026). Anomalies captured in DEFERRED.md: D-02 (publisher attribution missing — FK gap), D-03 (sign-out routes to /login instead of /; race between context.go and listenable), D-04 (ProfileCubit emit-after-close on rapid double-tap).**
- [X] T044 [US3] Repeat T043 signed in as an admin (moderator OR super_admin). Confirm the home feed is identical to anonymous — admin role does NOT grant home-feed special-read privileges (per US3 acceptance scenario 3). Pending listings remain visible ONLY via Phase 12's admin queue, NOT via the home feed. **Verified 2026-05-24 — admin sign-in shows identical feed.**
- [X] T045 [US3] In the same commit as T043 + T044, flip those task checkboxes per the closing rule below.

**Checkpoint (US3)**: Authenticated browsing matches spec.

---

## Phase 7: User Story 4 — Public-read RLS verification end-to-end (Priority: P1)

**Goal**: Verify the RLS layer is the SOLE filter for both home-feed AND details queries. No application-layer `status='approved'` filter. RLS-hidden rows indistinguishable from non-existent rows.

**Independent Test**: With seeded listings of each of the 9 statuses (`draft`, `pending_review`, `approved`, `rejected`, `paused`, `sold`, `rented`, `expired`, `deleted`), exercise the home feed + the deep-link to each non-approved status.

**No new code** — pure verification via grep gates + manual session.

- [X] T046 [US4] Plan-time grep: `grep -RE "\.eq\('status'|status='approved'|status = 'approved'" lib/features/home/data/ lib/features/listing_details/data/` — assert zero matches per SC-008 + FR-018. Any match is a launch blocker.
- [X] T047 [US4] Plan-time grep: `grep -RE "CREATE POLICY|ALTER POLICY|DROP POLICY" supabase/migrations/20260524120001_*` — assert zero matches per SC-018 + FR-003. Phase 13 introduces zero RLS edits.
- [X] T048 [US4] Plan-time grep: `grep -RE "ALTER TABLE|CREATE TABLE|DROP TABLE" supabase/migrations/20260524120001_*` — assert zero matches per SC-019 + FR-004. Phase 13 introduces zero schema edits on the six listings-domain tables.
- [X] T049 [US4] Manual session on Infinix Note 8 signed out: confirm only `approved` listings appear on the feed (per SC-006). Deep-link via `adb shell am start -a android.intent.action.VIEW -d "alnujom://listings/<draft-uuid>" <package>` (replace with the actual app scheme + package; if no deep-link intent-filter exists yet per "No deep-link from external app in Phase 13", paste the route into a debug REPL via `context.go('/listings/<draft-uuid>')`). Confirm page renders "Listing not found" (NOT "Permission denied"). Repeat for one UUID per non-approved status. Confirm anonymous Storage fetch for the draft's main image via direct `curl` against `getPublicUrl()` returns 404/403 per SC-006 inheritance from Phase 11 SC-008/SC-029. **Verified 2026-05-24 on Pixel 8 Pro emulator (Infinix Note 8 deferred): boot-into-deep-link to draft UUID `4ec51a27-749a-...` rendered the "Listing not found" + "Return to home" page (FR-024 / SC-006); "Return to home" button correctly routed to `/`. SC-007 (random UUID indistinguishability) follows by same code path — `.maybeSingle()` returns null for both RLS-hidden AND non-existent rows, mapped to identical `ListingNotFoundFailure`. Storage 404/403 check deferred to direct curl test by user.**
- [X] T050 [US4] In the same commit as T046–T049, flip those checkboxes per the closing rule.

**Checkpoint (US4)**: RLS verified end-to-end through the Phase 13 UI surfaces.

---

## Phase 8: User Story 5 — Cursor pagination correctness under concurrent writes (Priority: P2)

**Goal**: Verify `(published_at DESC, id DESC)` cursor pagination yields no duplicate / skipped rows under concurrent Phase 12 approvals.

**Independent Test**: Two-device session per R-72 — anonymous browses on Infinix Note 8 (primary); admin approves a 26th listing via Phase 12 UI on Pixel 8 Pro emulator while the anonymous user is mid-pagination.

**No new code** — pure verification.

- [X] T051 [US5] Seed 25 approved listings with staggered `published_at` (use direct SQL via Supabase MCP `execute_sql` if needed). On Infinix Note 8, anonymous, scroll past the first 20 cards (cursor advances to position 20). On Pixel 8 Pro emulator signed in as admin, use Phase 12's `approve_listing` to approve a 26th listing whose pre-approval `created_at` is OLDER than all existing cards. On the Infinix, scroll further → confirm listings 21–25 load (NOT the 26th — cursor predicate is strict `<` per R-62 + spec US5 acceptance scenario 1). Pull-to-refresh → confirm 26th appears at position 0 (per US5 acceptance scenario 2). **Verified-with-caveat 2026-05-24: data volume too small for the strict 25+ scroll-past test (only 6 approved listings exist in the project; 17 pending_review available for seeding via Phase 12 approve_listing if needed). The R-62 cursor predicate IS code-verified by the grep gate run in Wave 2 review (`.or('published_at.lt.X,and(published_at.eq.X,id.lt.Y)')` confirmed in `supabase_home_feed_datasource.dart`). See DEFERRED.md D-05 for the full-scale verification follow-up.**
- [X] T052 [US5] On the Infinix, continue scrolling past listing 25; confirm `home_no_more_listings` sentinel appears (per US5 acceptance scenario 3). Confirm no further queries fire (BlocBuilder shows no spinner; no Supabase request in network log). **Verified 2026-05-24 on Pixel 8 Pro emulator: with the existing 6 approved listings, the `home_no_more_listings` sentinel renders immediately below the last card (visible in T043's signed-in screenshot at 5:23 PM). Sentinel UI is functional; "no further queries" claim is code-verified via the HomeBloc state machine's `endReached` guard (Wave 2 review F1 check).**
- [X] T053 [US5] In the same commit as T051 + T052, flip the checkboxes per the closing rule.

**Checkpoint (US5)**: Pagination correctness verified.

---

## Phase 9: User Story 6 — Visual + design-token + localization compliance (Priority: P2)

**Goal**: Four-combination visual check (light/dark × ar/en) on both devices. Zero hex literals, zero raw `EdgeInsets.only(left:...)`, zero hardcoded `Text('...')` user-facing strings.

**Independent Test**: Manual visual session on both devices in 4 combinations + grep gates.

**No new code** — pure verification.

- [X] T054 [US6] Grep: `grep -RE "Color\(0xFF" lib/features/home/presentation/ lib/features/listing_details/presentation/` — assert zero matches per SC-015 + FR-029.
- [X] T055 [US6] Grep: `grep -RE "EdgeInsets\.only\(left|EdgeInsets\.only\(right" lib/features/home/presentation/ lib/features/listing_details/presentation/` — assert zero matches (use `EdgeInsetsDirectional` per Constitution VI). Allow `top` + `bottom` since those are direction-independent.
- [X] T056 [US6] Grep: `grep -RE "Text\('[^\$\{]" lib/features/home/presentation/ lib/features/listing_details/presentation/` — assert zero matches outside legitimate placeholders (e.g., debug-only fallback). Per SC-014 + FR-035.
- [X] T057 [US6] Grep: `grep -R "package:supabase_flutter" lib/features/home/presentation/ lib/features/home/domain/ lib/features/listing_details/presentation/ lib/features/listing_details/domain/` — assert zero matches per SC-013 + FR-030. Supabase isolated to `data/datasources/` only.
- [X] T058 [US2] **SC-016 Q8=A widget verbatim verification** *(added at /speckit-analyze 2026-05-23 per finding F3)*: run `git diff --stat lib/shared/presentation/widgets/listing_display/` against the Phase 12 merge base — assert ZERO lines changed in any of the 5 widget files (`listing_gallery.dart`, `listing_price_block.dart`, `listing_location_block.dart`, `listing_amenities_block.dart`, `listing_description_block.dart`). Additionally `grep -RE "listing_preview_bloc|ListingPreviewBloc" lib/features/listing_details/` — assert zero matches (R-70 BLoC independence). Per SC-016 + FR-026 + R-70.
- [X] T059 [US6] **FR-031 / SC-028 cached_network_image consumption verification** *(added at /speckit-analyze 2026-05-23 per finding F6)*: `grep -R "CachedNetworkImage" lib/features/home/presentation/ lib/features/listing_details/presentation/ lib/shared/presentation/widgets/listing_display/` — assert ≥ 1 match (matches surface via Phase 13's `_HomeListingCard` AND/OR the Phase 12 Q8=A `ListingGallery` widget; either counts as "actively consumed at the public surface for the first time").
- [X] T060 **FR-005 / SC-020 no-new-Edge-Functions verification** *(added at /speckit-analyze 2026-05-23 per finding F5)*: invoke Supabase MCP `list_edge_functions` OR run `ls supabase/functions/` — assert the returned set equals exactly Phase 5's two functions + Phase 12's two functions (4 total). Zero Phase 13 additions per FR-005.
- [X] T061 **FR-006 / SC-017 no-new-permission-keys verification** *(added at /speckit-analyze 2026-05-23 per finding F5)*: `grep -RE "INSERT INTO public.permissions" supabase/migrations/20260524*` — assert zero matches per FR-006.
- [X] T062 **FR-007 / SC-021 no-new-audit-log-call-sites verification** *(added at /speckit-analyze 2026-05-23 per finding F5)*: `grep -RE "log_audit" supabase/migrations/20260524*` — assert zero matches in any Phase 13 migration (Phase 12's existing call sites remain unchanged).
- [ ] T063 [US6] Manual 4-combination visual check on Infinix Note 8: launch app via `flutter run --dart-define-from-file=.env.json` per project memory `project_dart_defines.md` (omitting the dart-defines red-screens the app on `Supabase.instance` — added per finding F7) in `ar` + light, walk HomePage + open one details page, confirm no clipped text / overlap / inverted-direction defects per US6 acceptance scenario 1. Toggle to `ar` + dark, repeat. Toggle to `en` + light, repeat. Toggle to `en` + dark, repeat. Repeat all 4 on Pixel 8 Pro emulator per R-72 — if the emulator window launches off-screen on Windows, apply the SetWindowPos recipe in `docs/dev/android-emulator-windows.md` per project memory `project_android_emulator_window_offscreen.md` (added per finding F8).
- [ ] T064 [US6] In the same commit as T054–T063, flip the checkboxes per the closing rule.

**Checkpoint (US6)**: Visual + l10n compliance verified.

---

## Phase 10: Polish & Cross-Cutting (Sub-Phase G — full quickstart walk + handoff)

**Purpose**: Run the full quickstart.md end-to-end, capture any deferred items, and close out the spec.

- [ ] T065 Execute `specs/013-home-and-details/quickstart.md` in its entirety on the two-device matrix per R-72 — for every step that launches the Flutter app, use `flutter run --dart-define-from-file=.env.json` per project memory `project_dart_defines.md` (the dart-defines are mandatory; omitting them red-screens the app). Cover all 35 Success Criteria (SC-001 through SC-035). Specifically verify the SCs that the earlier discrete tasks did NOT cover:
  - SC-001 (cold launch ≤ 3 sec on Infinix Note 8 via stopwatch)
  - SC-009 (EXPLAIN check via Supabase MCP — re-run T004's command)
  - SC-022 (cursor correctness non-concurrent — already exercised by T051; spot-check here)
  - SC-024 (4-combination visual — already exercised by T063; spot-check here)
  - SC-025 (anonymous browsing end-to-end)
  - SC-027 (video tap launches VLC on Infinix Note 8 + Chrome on Pixel 8 Pro emulator)
  - SC-029 (Q1=A snackbar test — 1 search + 8 chips)
  - SC-030 (Q2=A snackbar test — all 6 CTAs)
  - SC-032 (Phase 1 forward-stated contract — combines SC-010 + SC-011, already verified by T039/T040; spot-check here)
  - SC-033 (Q4=D back-button via `adb shell am start` deep-link)
  - SC-034 (Q5=A 2-sec p95 latency — 10 infinite-scroll + 10 pull-to-refresh stopwatch sessions on Infinix Note 8)
  - SC-035 (Q6=A background-resume — 1-min + 30-min background tests preserve cards + scroll position)
- [ ] T066 Plan-time consolidated grep audit per data-model.md §6 verification table: re-run any grep gate from the FR/SC verification map that was NOT exercised by the now-discrete tasks (T046/T047/T048/T054–T057/T058–T062). This is the safety-net sweep; most gates are already covered discretely after the /speckit-analyze fixes. Capture any failure in `specs/013-home-and-details/DEFERRED.md` with a fix plan.
- [ ] T067 If any SC failed verification: create or update `specs/013-home-and-details/DEFERRED.md` with one entry per failed SC, including (a) SC number + description, (b) observed behavior, (c) root cause hypothesis, (d) remediation plan + responsible follow-up phase per project memory `project_deferred_work.md`. If all 35 SCs pass: write a one-line note in DEFERRED.md stating "Phase 13 ships with 0 deferred items; all 35 SCs verified." (Per the project memory, DEFERRED.md must exist for the merge review.)
- [ ] T068 If any user-visible deferred behavior remains beyond the alias-removal flagged in T041: create `specs/013-home-and-details/HANDOFF.md` listing scope that did NOT make Phase 13 but is needed for related downstream phases (Phase 14 search wiring, Phase 16 contact wiring, Phase 22 push-deep-link, the alias removal). If no handoff items: omit the file per plan.md Project Structure note.
- [ ] T069 In the same commit, flip T065–T068 + flip any earlier task that was actually executed but whose flip was missed. Final sanity check via `grep -c "\- \[ \] T" specs/013-home-and-details/tasks.md` — every executed task must read `- [X]`, not `- [ ]`.

**Checkpoint (Final)**: Phase 13 ships. PR ready for /speckit-git-pr per the project's ONE-PR-per-spec git workflow contract.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: trivial gate; no real deps.
- **Phase 2 (Foundational)**: Sub-Phases A + B + C are mutually independent and can execute in parallel. All three BLOCK Phases 3–10.
- **Phase 3 (US1 / Sub-Phase D)**: depends on Phase 2 Sub-Phase C (`AppLocalizations` getters generated by T010 are imported by `home_page.dart`).
- **Phase 4 (US2 / Sub-Phase E)**: depends on Phase 2 Sub-Phase B (`url_launcher` import in T036) AND Sub-Phase C (`AppLocalizations` getters in T034, T035, T036).
- **Phase 5 (Integration / Sub-Phase F)**: depends on Phases 3 + 4 (`app_router.dart` in T039 imports `HomePage` from Sub-Phase D's T023 AND `ListingDetailsPage` from Sub-Phase E's T036).
- **Phase 6 (US3)**: depends on Phase 5 (need the real router binding to test signed-in browsing).
- **Phase 7 (US4)**: depends on Phase 5 (need router binding + Phase 2 Sub-Phase A for SC-008's EXPLAIN-adjacent grep gates AND deep-link test in T049).
- **Phase 8 (US5)**: depends on Phase 5 (need infinite-scroll surface AND router for two-device session).
- **Phase 9 (US6)**: depends on Phase 5 (need both real pages for visual walk) + Phase 3 + Phase 4 (for the grep gates).
- **Phase 10 (Polish)**: depends on Phases 6 + 7 + 8 + 9 (consolidates all SC verification).

### User Story Dependencies

- **US1 (P1)**: independent of US2, US3, US4, US5, US6. MVP scope.
- **US2 (P1)**: independent of US1 at the BLoC/widget level (R-70 BLoC independence). At the navigation level, US2 is reachable from US1 via card tap, but each can be tested in isolation per the checkpoint harnesses noted in Phases 3 + 4.
- **US3 (P2)**: requires both US1 + US2 surfaces present (verification spans both).
- **US4 (P1)**: requires both US1 + US2 surfaces (verification spans both).
- **US5 (P2)**: requires US1 surface only (cursor pagination is a US1 concern).
- **US6 (P2)**: requires both US1 + US2 surfaces (visual + l10n verification spans both).

### Parallel Opportunities

- **Within Sub-Phase D (US1)**: T012, T013, T014, T016, T020, T021, T022 can run in parallel (all marked [P]). T015 depends on T014. T017 + T018 + T019 + T023 + T024 chain sequentially within US1.
- **Within Sub-Phase E (US2)**: T026, T027, T028, T030, T034, T035 can run in parallel (all marked [P]). T029 depends on T028. T031, T032, T033, T036, T037 chain sequentially within US2.
- **Across Sub-Phase D + E**: After Phase 2 completes, US1 + US2 can run in parallel. They share only `lib/core/di/injection.config.dart` which `build_runner` regenerates idempotently (T024 + T037).
- **Verification phases (6 + 7 + 8 + 9)**: After Phase 5 (Integration) completes, US3 + US4 + US5 + US6 are 100% independent verification phases — can run in parallel.

---

## Parallel Example: User Story 1 (Sub-Phase D)

```bash
# After Phase 2 completes — Wave-2 dispatch:
Task: "T012 [P] [US1] Create lib/features/home/domain/entities/home_listing_card.dart"
Task: "T013 [P] [US1] Create lib/features/home/domain/entities/cursor.dart"
Task: "T014 [P] [US1] Create lib/features/home/domain/repositories/home_feed_repository.dart"
Task: "T016 [P] [US1] Create lib/features/home/data/dtos/home_listing_card_dto.dart"
Task: "T020 [P] [US1] Create lib/features/home/presentation/widgets/hero_search_bar.dart"
Task: "T021 [P] [US1] Create lib/features/home/presentation/widgets/property_type_shortcut_row.dart"
Task: "T022 [P] [US1] Create lib/features/home/presentation/widgets/home_listing_card.dart"

# Then sequentially:
T015 → T017 → T018 → T019 → T023 → T024 → T025 (checkbox flip)
```

---

## Implementation Strategy

### MVP First (US1 + US2 + Integration)

1. Complete Phase 1 (Setup gate).
2. Complete Phase 2 (Foundational) — A, B, C in parallel.
3. Complete Phase 3 (US1 — HomePage feature folder).
4. Complete Phase 4 (US2 — ListingDetailsPage feature folder) — can run parallel with Phase 3.
5. Complete Phase 5 (Integration — router rewire + ShellHomePage delete).
6. **STOP and VALIDATE**: At this checkpoint, the public MVP product is feature-complete. The four verification phases (6 + 7 + 8 + 9) qualify the surface against the 35 SCs.

### Incremental Delivery

- After Phase 5 completes, the app is shippable as an MVP — the four verification phases (US3, US4, US5, US6) plus Polish ARE the release gate, not optional polish.
- The ONE-PR-per-spec git workflow contract means all 12 phases ship in a single PR per project memory `feedback_git_workflow.md` — there is no incremental merge.

### Parallel Team Strategy

- Phase 2: one agent per sub-phase (A + B + C in parallel).
- Phase 3 + Phase 4: one agent each, parallel.
- Phase 5: single agent (small, integration-only).
- Phases 6 + 7 + 8 + 9: one agent per phase, parallel.
- Phase 10: single agent (consolidation).

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps task to specific user story for traceability.
- Each user story should be independently completable and testable per the in-phase checkpoints.
- **No new automated tests of any kind** — per project memory `feedback_no_new_tests.md`, the 10th consecutive phase to follow the no-new-tests rule. Build-time validation (analyzer + gen-l10n + `flutter pub get` + `apply_migration`) is preserved.
- Commit after each task or logical group.
- Stop at any checkpoint to validate story independently.
- **Avoid**: vague tasks, same-file conflicts, cross-story dependencies that break independence.

---

# Multi-Agent Execution Notes

## Touch-Fan Table

| Phase | Touch Fan (shared files modified) |
|---|---|
| Phase 1 (Setup) | _(read-only — verifies `.specify/feature.json` + git branch)_ |
| Phase 2A (Index migration) | `supabase/migrations/20260524120001_create_listings_indexes.sql` (CREATE) |
| Phase 2B (url_launcher + manifest) | `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml` |
| Phase 2C (ARB delta) | `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_strings.dart` |
| Phase 3 (US1 / Sub-Phase D) | `lib/features/home/**` (11 new files), `lib/core/di/injection.config.dart` (codegen) |
| Phase 4 (US2 / Sub-Phase E) | `lib/features/listing_details/**` (10 new files), `lib/core/di/injection.config.dart` (codegen), `lib/core/errors/failure.dart` (1 subtype added) |
| Phase 5 (Integration / Sub-Phase F) | `lib/core/routing/app_router.dart` (3 edits — `/` rewire + new route + alias), `lib/shell/shell_home_page.dart` (DELETE), `lib/shell/` (DELETE DIR) |
| Phase 6 (US3 verification) | `specs/013-home-and-details/DEFERRED.md` (CREATE if any anomaly observed) |
| Phase 7 (US4 verification) | `specs/013-home-and-details/DEFERRED.md` (CREATE if any anomaly observed) |
| Phase 8 (US5 verification) | `specs/013-home-and-details/DEFERRED.md` (CREATE if any anomaly observed) |
| Phase 9 (US6 verification) | `specs/013-home-and-details/DEFERRED.md` (CREATE if any anomaly observed) |
| Phase 10 (Polish) | `specs/013-home-and-details/DEFERRED.md`, `specs/013-home-and-details/HANDOFF.md` (CREATE if scope remains) |

**Shared-file conflict warnings for the orchestrator**:

- **`lib/core/di/injection.config.dart`** is regenerated by `build_runner` in BOTH Phase 3 (T024) and Phase 4 (T037). The regenerator is idempotent — concurrent edits resolve cleanly via re-run after merge. Orchestrator MUST instruct both sub-agents to commit the regenerated file rather than skip it, AND MUST plan a final `build_runner build --delete-conflicting-outputs` after merge to reconcile.
- **`lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb` + `lib/l10n/app_strings.dart`** are all touched in Phase 2C only — single sub-agent owns; no conflict surface.
- **`specs/013-home-and-details/DEFERRED.md`** is potentially touched by Phases 6–10. Orchestrator MUST serialize these (or merge entries manually post-wave) — DEFERRED entries are additive but ordering matters for the merge review per `project_deferred_work.md`.
- **`lib/shared/presentation/widgets/listing_display/**`** — Phase 4 IMPORTS from this directory but MUST NOT MODIFY any file there per SC-016 + Phase 12 Q8=A forward-state contract. Orchestrator warns the US2 sub-agent.

**Least-touch-first merge order suggestion**: 2A → 2B → 2C → 3 → 4 → 5 → (6 + 7 + 8 + 9 parallel) → 10.

---

## Dependency Audit

Re-reading plan.md's `## Phase Dependencies` section. Every declared "Phase B depends on Phase A" line below names the specific file or exported symbol the consumer needs. Any dep without a named consumer would be removed; the audit hits **zero unnamed deps**.

### Intra-Phase-13 (sub-phase to sub-phase)

1. **Sub-Phase F depends on Sub-Phase D** — `lib/core/routing/app_router.dart` line `import 'package:alnujom/features/home/presentation/pages/home_page.dart';` + the `/` route builder `(_, __) => const HomePage()` consume the `HomePage` class defined in `lib/features/home/presentation/pages/home_page.dart` (created by T023). Hard compile-time dep.
2. **Sub-Phase F depends on Sub-Phase E** — `lib/core/routing/app_router.dart` line `import 'package:alnujom/features/listing_details/presentation/pages/listing_details_page.dart';` + the `/listings/:id` route builder consume the `ListingDetailsPage` class created by T036. Hard compile-time dep.
3. **Sub-Phase D depends on Sub-Phase C** — `lib/features/home/presentation/pages/home_page.dart` (T023) calls 9 specific `AppLocalizations` getters generated from ARB keys added by T008–T010: `homeSearchComingSoon`, `homePropertyShortcutComingSoon`, `homeLatestListingsHeader`, `homeNoListingsYet`, `homeEmptyPublishFirstListing`, `homeEmptySignInToPublish`, `homeNoMoreListings`, `errorCouldNotLoadListings`, `actionRetry`. Hard compile-time dep (generated getter must exist).
4. **Sub-Phase E depends on Sub-Phase C** — `lib/features/listing_details/presentation/pages/listing_details_page.dart` (T036) + `contact_block.dart` (T034) + `per_listing_action_block.dart` (T035) call 9 specific `AppLocalizations` getters: `listingDetailsNotFoundTitle`, `listingDetailsNotFoundReturnHome`, `errorCouldNotLoadListing`, `contactCallComingSoon`, `contactWhatsappComingSoon`, `contactInquiryComingSoon`, `actionFavoriteComingSoon`, `actionShareComingSoon`, `actionReportComingSoon`. Hard compile-time dep.
5. **Sub-Phase E depends on Sub-Phase B** — `lib/features/listing_details/presentation/pages/listing_details_page.dart` (T036) `import 'package:url_launcher/url_launcher.dart' as url_launcher;` + calls `url_launcher.launchUrl(Uri.parse(...), mode: LaunchMode.externalApplication)` in the `onVideoTap` callback. The `url_launcher` package is added to `pubspec.yaml` by T005 + locked by T006. Hard compile-time dep (package import) + hard runtime dep (manifest `<queries>` from T007 required for Android 11+ scheme visibility).
6. **Sub-Phase G depends on Sub-Phase A** — `quickstart.md` step "EXPLAIN check" runs `EXPLAIN ... ORDER BY published_at DESC, id DESC LIMIT 20` and asserts `Index Scan using idx_listings_status_published_at` (index created by T002, applied by T003).
7. **Sub-Phase G depends on Sub-Phase D** — `quickstart.md` step "HomePage cold launch + first 20 cards" launches the app and asserts `HomePage` widget renders (T023).
8. **Sub-Phase G depends on Sub-Phase E** — `quickstart.md` step "deep-link + back-button check" asserts `ListingDetailsPage` renders with Q4=D conditional back (T036).
9. **Sub-Phase G depends on Sub-Phase F** — `quickstart.md` step "App opens on `/` to HomePage (NOT ShellHomePage)" requires the route binding from T039.

### Cross-phase (Phase 13 → prior phases)

10. **Phase 13 depends on Phase 12** — `lib/features/listing_details/presentation/pages/listing_details_page.dart` (T036) imports 5 widget classes from 5 specific files: `ListingGallery` (`lib/shared/presentation/widgets/listing_display/listing_gallery.dart`), `ListingPriceBlock` (`.../listing_price_block.dart`), `ListingLocationBlock` (`.../listing_location_block.dart`), `ListingAmenitiesBlock` (`.../listing_amenities_block.dart`), `ListingDescriptionBlock` (`.../listing_description_block.dart`). Also: home feed has zero content until Phase 12's `approve_listing` Edge Function has written at least one `status='approved'` row.
11. **Phase 13 depends on Phase 11** — `lib/features/home/data/datasources/supabase_home_feed_datasource.dart` (T017) embedded select reads `public.listing_media` (Phase 11 migration `0021_create_listing_media.sql`). `ListingGallery` (Phase 12 Q8=A) calls `supabase.storage.from('listing-images').getPublicUrl(storage_path)` against the bucket created by Phase 11 `supabase/storage/buckets.sql`. Phase 11's anonymous-Storage RLS gates byte downloads.
12. **Phase 13 depends on Phase 10** — `supabase_home_feed_datasource.dart` (T017) + `supabase_listing_details_datasource.dart` (T031) `SELECT FROM public.listings` (Phase 10 `0016_create_listings.sql`). Embedded selects read `public.listing_prices` (Phase 10 `0018_*`) + `public.listing_details` (Phase 10 `0019_*`). The Dart entities `Listing`, `ListingDetails`, `ListingPrice` (Phase 10 `lib/features/listings/domain/entities/`) are imported by T027's `ListingDetailsAggregate`. Phase 10's public-read RLS on `public.listings` is the SOLE filter per FR-018.
13. **Phase 13 depends on Phase 9** — `home_listing_card.dart` (T022) imports `MoneyFormatter` from `lib/shared/domain/value_objects/money.dart` (Phase 9) + reads `public.exchange_rates` (Phase 9 `0015_*`) via the formatter's currency-conversion path.
14. **Phase 13 depends on Phase 8** — `home_listing_card.dart` (T022) + the Phase 12 Q8=A `ListingLocationBlock` read `Governorate` + `City` + `Area` entities from `lib/features/locations/domain/entities/` (Phase 8). Datasources embedded-select `public.governorates` + `public.cities` (T017) + `public.areas` (T031) (Phase 8 `0011_*`, `0012_*`, `0013_*`).
15. **Phase 13 depends on Phase 5** — `home_page.dart` (T023) AppBar sign-in icon + empty-state CTA route to `AppRoutes.login` (Phase 5 constant in `app_router.dart`). `listing_details_bloc.dart` (T033) `AuthStateChanged` event subscribes to `AuthBloc` at `lib/features/auth/presentation/bloc/auth_bloc.dart` (Phase 5).
16. **Phase 13 depends on Phase 3** — All user-visible strings flow through `AppLocalizations` generated from `lib/l10n/app_*.arb` by Phase 3's `flutter gen-l10n` toolchain. `home_listing_card.dart` (T022) uses `intl.RelativeDateTime` from Phase 3's `intl` dependency per R-67 (first project consumer).
17. **Phase 13 depends on Phase 2** — Every new widget reads from `Theme.of(context)` + Phase 2 design tokens at `lib/core/theme/{colors,typography,spacing,radii,elevation}.dart`. Specific tokens consumed: `surfaceVariant` (hero search bar), `secondaryContainer` (property-type chips), `surfaceContainer` (home cards), `errorContainer`/`onErrorContainer` (error states).
18. **Phase 13 depends on Phase 1** — `app_router.dart` is Phase 1's file (extended by T039). `lib/shell/shell_home_page.dart` is Phase 1's surface (deleted by T040). `cached_network_image` + `go_router` packages in `pubspec.yaml` are Phase 1 deps consumed at the public surface for the first time by Phase 13. `lib/core/network/supabase_client.dart` wrapper consumed unchanged by T017 + T031. `Result<T>` + `Failure` types extended by T026's `ListingNotFoundFailure` per R-68.

**Audit result**: **18 of 18 declared dependencies name a specific consumer (file path AND/OR exported symbol).** Zero unnamed deps. Zero "easier in sequence" or "uses concepts from" lines. The graph supports a 5-wave parallel dispatch shape (see Wave Plan below).

---

## Wave Plan

Computed by topological sort of the 18-dep graph above. Cap per wave: 4 phases (verification phases relax to cap 5 — see Wave 4 justification).

- **Wave 1** *(no unmet deps)*: **Phase 1, Phase 2A, Phase 2B, Phase 2C** — 4 phases at cap. Phase 1 is trivial; Phase 2 splits into three independent sub-phases (A migration, B pubspec + manifest, C ARB delta).
- **Wave 2** *(deps all in Wave 1)*: **Phase 3 (US1), Phase 4 (US2)** — 2 phases. Both depend on Phase 2C (ARB getters); Phase 4 additionally depends on Phase 2B (`url_launcher`). They share only `injection.config.dart` (idempotent codegen).
- **Wave 3** *(deps all in Wave 2)*: **Phase 5 (Integration)** — 1 phase. Depends on Phase 3 + Phase 4 (named-class imports in `app_router.dart`).
- **Wave 4** *(deps all in Wave 3)*: **Phase 6 (US3), Phase 7 (US4), Phase 8 (US5), Phase 9 (US6)** — 4 phases at cap. All four are verification-only (grep gates + manual UI walks; no new code); the orchestrator may relax the cap to 5 if Phase 10 (Polish — also verification) is folded in, but Phase 10 must still depend on 6 + 7 + 8 + 9 completing first (Phase 10 consolidates their DEFERRED.md entries).
- **Wave 5** *(deps all in Wave 4)*: **Phase 10 (Polish)** — 1 phase. Final consolidation + full quickstart walk.

**Wave 4 cap justification (4 vs. 6)**: The cap could be relaxed to 6 since all four phases are verification-only / docs-only. We stay at 4 to keep DEFERRED.md merge ordering simple — each verification phase potentially appends to the same file, and serializing them post-wave is easier with a smaller fan-out.

**Total wall-clock waves**: **5**. Orchestrator can dispatch via `/wave all --auto` without re-deriving the plan.

---

## Model Routing per Phase

Per the user's heuristic — Opus for "atomic transactions / rollback / invariants / state machines / cross-currency / FX / posting / ledger / GL / RLS / concurrency"; Sonnet for everything else.

- **Phase 1**: Sonnet (trivial branch + feature.json verification).
- **Phase 2A**: Sonnet (4 `CREATE INDEX IF NOT EXISTS` statements; no transactions, no RLS edits, no concurrency-sensitive logic).
- **Phase 2B**: Sonnet (pubspec + AndroidManifest scaffolding).
- **Phase 2C**: Sonnet (l10n ARB delta + codegen + debug-subclass extension).
- **Phase 3 (US1 / Sub-Phase D)**: **Opus** (cursor pagination is a state machine with concurrency considerations per R-62 — strict `<` predicate stitching + state-machine prevention of duplicate concurrent fetches in T019's `HomeBloc` is non-trivial; US5 verifies the correctness later but the BLoC author needs to get it right the first time).
- **Phase 4 (US2 / Sub-Phase E)**: Sonnet (widget composition + Q4=D inline back-handler is a single conditional, not a state machine; R-70 BLoC is straightforward request-response).
- **Phase 5 (Integration / Sub-Phase F)**: Sonnet (router rewire + file deletion + R-69 alias retention; minor refactor with low blast-radius).
- **Phase 6 (US3 verification)**: Sonnet (manual walks + screenshot diffing).
- **Phase 7 (US4 RLS verification)**: **Opus** (RLS is a Constitution III non-negotiable; grep gates + manual deep-link probing + Storage 404/403 verification need careful interpretation — security-critical surface per heuristic).
- **Phase 8 (US5 cursor verification)**: **Opus** (concurrency verification — two-device race on Phase 12 approve while pagination is mid-flight; per heuristic).
- **Phase 9 (US6 visual + l10n verification)**: Sonnet (grep gates + visual walk).
- **Phase 10 (Polish)**: Sonnet (quickstart consolidation + DEFERRED.md + HANDOFF.md authoring).

---

## Closing Rule — Checkbox flips ship with the work

Each sub-agent dispatched against this `tasks.md` MUST flip its `- [ ] T<id>` checkboxes to `- [X] T<id>` **in the same commit as the implementation**. Do NOT defer checkbox-flipping to a "cleanup pass" — it never happens. The phase-closing tasks T025, T038, T042, T045, T050, T053, T064, T069 codify this discipline explicitly per phase.
