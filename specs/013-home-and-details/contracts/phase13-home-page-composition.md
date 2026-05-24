# Contract: HomePage Composition

**Path**: `lib/features/home/presentation/pages/home_page.dart`
**Implements**: FR-013, FR-016, FR-017, FR-019
**Verifies**: SC-001, SC-002, SC-003, SC-024, SC-025, SC-026, SC-029, SC-034, SC-035

## Composition order (top-to-bottom)

1. `AppBar`:
   - **Start side**: AlNujom brand mark (text + optional logo per Phase 2 token).
   - **End side**: Sign-in icon (anonymous) OR profile-avatar icon (authenticated) — `BlocSelector<AuthBloc, AuthState, bool>` picks. Tooltip per `home_sign_in_icon_tooltip` ARB key.

2. `_HeroSearchBar`:
   - `Container` styled per Phase 2 `surfaceVariant` token + `radii.md`.
   - Leading `Icon(Icons.search)` per Phase 2 icon-tokens.
   - Trailing localized placeholder text `home_search_bar_placeholder`.
   - Tap handler: dismiss keyboard if any + show snackbar `home_search_coming_soon` per Q1=A. NO navigation.

3. `_PropertyTypeShortcutRow`:
   - Horizontal `SingleChildScrollView` (or `ListView.builder` with `scrollDirection: Axis.horizontal`) of 8 `_PropertyTypeChip` widgets.
   - The 8 types per §6.3 enum: `apartment`, `villa`, `land`, `shop`, `office`, `farm`, `warehouse`, `other`.
   - Each chip: `Chip(label: <localized type name>, avatar: Phase 2 icon for the type)` per Phase 2 `secondaryContainer` token.
   - Tap handler per chip: dismiss keyboard if any + show snackbar `home_property_shortcut_coming_soon` parameterized with the tapped type's localized label per Q1=A. NO navigation.

4. Section header: `Text(localizations.home_latest_listings_header, style: Theme.of(context).textTheme.titleLarge)` per Phase 2 typography.

5. Paginated feed (driven by `HomeBloc`):
   - `RefreshIndicator` wraps the `ListView.builder`.
   - On pull-down: `HomeBloc.add(HomeFeedRefreshRequested())`.
   - `ScrollController` listener: when `position.pixels >= position.maxScrollExtent - threshold`, fires `HomeBloc.add(HomeFeedNextPageRequested())`. Threshold default: 5 cards from bottom (plan-time-codifiable).
   - `BlocBuilder<HomeBloc, HomeState>`:
     - `initial` / `loading` → centered `CircularProgressIndicator`.
     - `success` with `listings.isEmpty` → renders FR-019 empty-state.
     - `success` with `listings.isNotEmpty` → renders `ListView.builder` of `_HomeListingCard` widgets + a footer per status (`loadingMore` → spinner; reached end → `home_no_more_listings` sentinel text).
     - `error` → renders FR-014 "Could not load listings" Text + Retry button firing `HomeBloc.add(HomeFeedLoadRequested())`.
     - `refreshing` / `loadingMore` → existing list preserved + non-blocking spinner overlay.

## Empty-state UX (FR-019)

When `state.listings.isEmpty` AND `state.status == success`:

- Centered icon + localized `home_no_listings_yet` Text.
- CTA branched on auth state via `BlocSelector<AuthBloc, AuthState, AuthStatus>`:
  - Authenticated approved-publisher: `OutlinedButton.icon(label: home_empty_publish_first_listing, onPressed: () => context.go(Phase 10's listing-form route))`.
  - Anonymous OR non-publisher: `OutlinedButton.icon(label: home_empty_sign_in_to_publish, onPressed: () => context.go(AppRoutes.login))`.

## Q4=D back-button (HomePage is the root)

HomePage is the `/` route — `Navigator.canPop()` is always FALSE at the HomePage. Android system back gesture: standard Flutter `WillPopScope` handling (allow OS to background the app) — NO special handling needed.

## Q6=A background→foreground resume

No `WidgetsBindingObserver` registered. The `HomeBloc` is created once at app startup via DI; its state persists across widget tree disposal/reconstruction. When the app foregrounds, the existing `HomeState` is re-bound and the `ListView.builder` rebuilds from the cached `listings` list at the cached scroll position (via `PageStorageKey` if Flutter's default scroll-restore isn't sufficient — plan-time-decided).

## Performance budgets per Q5=A

- Cold launch to first 20 cards rendered: ≤ 3 sec on Infinix Note 8 per SC-001 (cold-launch overhead is the dominant cost; the SELECT is sub-second).
- Infinite-scroll next-page: ≤ 2 sec p95 per SC-034.
- Pull-to-refresh: ≤ 2 sec p95 per SC-034.

## Constitution compliance

- **V** (l10n): every string flows through `AppLocalizations`. SC-014 verifies.
- **VI** (design tokens): every widget reads from `Theme.of(context)`; zero inline hex / pixel constants. SC-015 verifies.
- **IX** (Supabase isolation): zero `package:supabase_flutter` imports in `presentation/`. SC-013 verifies.
- **XI** (Android-first): no platform-conditional code.
