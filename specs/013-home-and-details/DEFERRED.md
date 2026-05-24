# Phase 13 Deferred Items

## D-01 — Follow-up alias removal: `AppRoutes.shellHome` / `AppRouteNames.shellHome`

**Introduced by**: T041 (Sub-Phase F — Routing rewire)

**Status**: Retained per R-69 — interim back-compat aliases are intentional for one PR lifetime.

**Detail**: Sub-Phase F renamed `AppRoutes.shellHome` → `AppRoutes.home` (value `'/'`) and
`AppRouteNames.shellHome` → `AppRouteNames.home` (value `'home'`). Both old names are retained
as `static const shellHome = home;` aliases in `lib/core/routing/app_router.dart`.

**In-tree consumers still on the alias (4 call sites across 2 files)**:
- `lib/features/auth/presentation/pages/publisher_approval_pending_page.dart` line 37:
  `context.go(AppRoutes.shellHome)` — resolves correctly via alias.
- `lib/features/listing_form/presentation/pages/listing_form_page.dart` lines 78, 81, 91:
  three `context.go(AppRoutes.shellHome)` calls — all resolve correctly via alias.

**Decision**: Left on alias intentionally (not migrated in this commit) to keep the diff minimal
for the Phase 13 PR review. The alias resolves to `AppRoutes.home` (`'/'`) at compile time — no
behavioral difference.

**Remediation**: In a follow-up PR (or Phase 14 prep), replace all four `AppRoutes.shellHome`
references with `AppRoutes.home` and delete the `static const shellHome = home;` lines from both
`AppRoutes` and `AppRouteNames`.

**Responsible phase**: Phase 14 (search surface) or a standalone cleanup PR — whichever touches
`listing_form_page.dart` or `publisher_approval_pending_page.dart` first.

## D-02 — ListingDetailsPage publisher attribution missing (`listings.publisher_user_id` has no FK)

**Introduced by**: T031 (Sub-Phase E — SupabaseListingDetailsDatasource embedded select)
**Surfaced by**: Manual verification on the Pixel 8 Pro emulator during Wave 4 — PostgREST
returned `PGRST200: Could not find a relationship between 'listings' and 'profiles' in the schema
cache. Searched for a foreign key relationship between 'listings' and 'profiles' using the hint
'listings_publisher_user_id_fkey'`.

**Root cause**: `data-model.md` §3.1 assumed there was a FK constraint
`listings_publisher_user_id_fkey` between `public.listings.publisher_user_id` and
`public.profiles`. Checked at verification time: `public.listings` has 3 FKs (governorate_id,
city_id, area_id) and NONE on `publisher_user_id`. `public.profiles` has 0 FKs (no FK to
`auth.users(id)` either). PostgREST cannot embed via FK hint without the constraint.

**Workaround applied in Phase 13**: removed the `publisher:profiles!listings_publisher_user_id_fkey(...)`
line from `supabase_listing_details_datasource.dart` embedded select. The DTO's existing empty-
publisher fallback handles the missing key gracefully — ListingDetailsPage renders without the
publisher attribution label. All other listing-details content (gallery, price, location,
amenities, description, CTAs) renders correctly.

**User-visible impact**: the "by {name}" publisher attribution does not appear on the listing
details page. Listings remain fully browsable and the contact CTAs (which are stub snackbars per
Q2=A) work as designed.

**Remediation options** (pick one in a follow-up spec):
1. Add the missing FK via a migration: `ALTER TABLE public.listings ADD CONSTRAINT
   listings_publisher_user_id_fkey FOREIGN KEY (publisher_user_id) REFERENCES auth.users(id) ON
   DELETE CASCADE` + a matching FK from `public.profiles.user_id` to `auth.users(id)`. After
   schema cache refresh, restore the embedded select.
2. Do a second PostgREST query after fetching the listing: `_client.from('profiles').select('full_name, username').eq('user_id', listing.publisherUserId).maybeSingle()`. Costs one
   extra round-trip per details-page render.
3. Use a Postgres view that pre-joins `listings` + `profiles` on `publisher_user_id = user_id`,
   then SELECT from the view. Centralises the join but adds a view + RLS-on-view maintenance
   burden.

**Responsible phase**: a Phase 5 / Phase 10 schema follow-up (option 1) OR Phase 16 inquiry
wiring (which already needs publisher contact data, so a follow-up query/view fits naturally).

## D-03 — Sign-out routes to /login instead of / (race condition)

**Introduced by**: Phase 5's auth-redirect logic interacting with Phase 13's ProfilePage logout tap handler.
**Surfaced by**: T043 manual verification on Pixel 8 Pro emulator 2026-05-24.

**Symptom**: After signing in and tapping Sign Out on ProfilePage, the user is routed to `/login`
instead of `/` (the public home). Functionally the user IS signed out cleanly — the AuthBloc
transitions to `Unauthenticated`, the router redirects — but they land on `/login` rather than
the public home as FR-008 implies.

**Root cause**: race condition between `context.go(AppRoutes.home)` (called from the logout tap
handler so the user immediately leaves /profile) and `AuthBlocListenable.notifyListeners()` (fired
when the bloc emits `Unauthenticated`). The listenable fires BEFORE `context.go('/')` completes,
so the router re-evaluates the redirect against the still-current `/profile` path. Since
`/profile` is not in `_publicPaths`, `_redirectIfProtected('/profile')` returns `/login`.

**Workaround user can apply**: tap the brand title or the sign-in icon to navigate back to `/`.

**Remediation options** (pick one in a follow-up spec):
1. Defer the `context.go(AppRoutes.home)` call by one microtask so the bloc emit fires first,
   then the navigation runs against an already-Unauthenticated state that resolves cleanly.
2. Add `/profile` to a "stay-here-after-signout-then-redirect-to-home" allowlist in the auth
   redirect (more complex but more explicit).
3. Have the auth-redirect logic detect "user is on `/profile` AND state is Unauthenticated" and
   return `AppRoutes.home` instead of `/login`. Same logic could apply to any other future
   authenticated-only page that doesn't explicitly require login.

**Responsible phase**: a Phase 5 auth-redirect follow-up OR a Phase 13 polish patch if it
proves blocking for additional flows.

## D-04 — `ProfileCubit` emit-after-close race on rapid navigation

**Introduced by**: Phase 5's `ProfileCubit.load()` + `loadRoles()` — pre-existing latent bug,
surfaced by Phase 13's verification when the user rapid-taps the profile icon (creating two
sequential BlocProvider instances of ProfileCubit; the first closes when the second mounts).

**Surfaced by**: T043 verification 2026-05-24 — log shows two `Unhandled Exception: Bad state:
Cannot emit new states after calling close` errors with stack traces pointing to
`profile_cubit.dart:37` (load) and `profile_cubit.dart:103` (loadRoles).

**Symptom**: console errors printed; the app does not crash; the eventually-shown ProfilePage
renders correctly. The errors are cosmetic but pollute the log and could become latent issues
under tighter error-monitoring (e.g., Phase 24 observability).

**Root cause**: `ProfileCubit.load()` and `loadRoles()` are async and emit after `await`. When
the BlocProvider that owns the cubit is disposed (e.g., user navigated away during the in-flight
load), the cubit is closed but the pending awaits eventually resolve and try to `emit()`.

**Remediation**: guard each `emit` call with `if (!isClosed) emit(...)` in `ProfileCubit`. Tiny
one-line-per-emit patch (~7 sites in the file).

**Responsible phase**: a Phase 5 polish patch (not Phase 13's responsibility) OR roll into the
Phase 22 push/Realtime work which may also touch the cubit.
