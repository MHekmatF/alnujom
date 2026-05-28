# Phase 0 Research — Favorites (Phase 17)

Ten plan-time decisions (R-109..R-118). Each records the decision, rationale, and rejected alternatives. These resolve every NEEDS-CLARIFICATION-class question the Technical Context raised; the spec's 6 product clarifications (Q1..Q6) are recorded separately in `spec.md`.

---

## R-109 — No new dependencies

**Decision**: Phase 17 adds ZERO new pubspec packages and enables ZERO new Postgres extensions.

**Rationale**: Favorites are a toggle + a list + a private table. Every primitive needed already exists: `flutter_bloc` for the cubit/bloc, `go_router` for `/favorites`, `supabase_flutter` for the table/RPC/view reads (in `data/` only), `cached_network_image` for the card images, `equatable` for entities, and `intl` for any timestamp formatting. A third-party "wishlist/favorites" package would violate FR-030 and add review surface for no gain. The `favorite_added` lead event already exists in `public.lead_events` (Phase 16), so no schema change there either.

**Alternatives considered**: A dedicated local-cache package (e.g., for offline favorites) — rejected: favorites are server-authoritative (FR-009 / US4) and the session `Set<String>` is sufficient in-memory; offline favorites are a future spec.

---

## R-110 — Cross-surface consistency via a shared `FavoritesCubit` lazySingleton

**Decision**: A `FavoritesCubit` registered `@lazySingleton` holds the signed-in user's favorited-listing-id `Set<String>`. It hydrates on sign-in (one `LoadFavoriteIds` read), clears on sign-out, and is the single source of truth for every heart's filled/empty state. Each `FavoriteHeartButton` is a `BlocSelector<FavoritesCubit, FavoritesState, bool>` keyed on `isFavorited(listingId)`.

**Rationale**: FR-005 requires a listing favorited on one surface to show as favorited on every other surface within a session, with no per-card round-trip. A single in-memory set, mutated optimistically on toggle and shared across all card surfaces + the details CTA + the FavoritesPage, delivers this for free — a toggle re-emits the set and every visible heart keyed on that id rebuilds. This mirrors the Phase 16 `InquiriesUnreadCubit` shared-singleton pattern (`getIt<InquiriesUnreadCubit>()` consumed by both the home AppBar action and the inquiry-detail decrement path), so the codebase already has the precedent.

**Alternatives considered**: (a) Per-card `FutureBuilder` checking favorited state — rejected: N server reads per screen, slow + chatty, and no cross-surface coherence. (b) A `ValueNotifier<Set<String>>` in a plain singleton — rejected: Constitution IV defaults to BLoC/Cubit; the cubit gives testable state + the `AuthBloc` subscription hook.

---

## R-111 — Asymmetric write path: add via RPC, remove via RLS DELETE

**Decision**: Adding a favorite goes through `public.add_favorite(uuid)` (SECURITY DEFINER); removing goes through a direct client `DELETE` gated by the `favorites_delete_self` self-only RLS policy. No `remove_favorite` RPC.

**Rationale** (Q5=A): The add path MUST co-transactionally (and conditionally) emit the `favorite_added` event, and MUST be bypass-proof — so it has to be a SECURITY DEFINER function, and no direct client INSERT grant can exist (else a client could insert a favorite without the event). The remove path emits no event and has no co-transactional work; a self-only `DELETE` RLS policy expresses it idiomatically and lets the client delete directly. Adding a `remove_favorite` RPC would be empty ceremony that buys nothing over the policy.

**Alternatives considered**: A symmetric `remove_favorite` RPC for full "no direct grants" parity with Phase 16 — rejected as ceremony (Q5 explicitly chose the RLS DELETE). A single `toggle_favorite` RPC — rejected: it would have to read current state then branch, racing with the optimistic UI, and it muddies the "add emits, remove doesn't" event contract.

---

## R-112 — `favorite_added` dedup via the lead_events history

**Decision**: The `add_favorite` RPC emits the `favorite_added` event only when `NOT EXISTS (SELECT 1 FROM public.lead_events WHERE user_id = auth.uid() AND listing_id = p_listing_id AND event_type = 'favorite_added')`. The favorites table itself stays a plain hard-delete toggle with no history/`is_active` column.

**Rationale** (Q3=B): The event must fire once per `(user, listing)` ever. The `lead_events` table is append-only and already records every prior `favorite_added`, so it IS the prior-favorite memory — a single `EXISTS` guard inside the same transaction gives the dedup with no extra schema. Keeping `favorites` as a simple `(user_id, listing_id)` row with hard-delete-on-remove keeps the table and its RLS trivially auditable.

**Alternatives considered**: (a) A soft-delete `is_active` flag on `favorites` — rejected: more complex schema + RLS, and the `lead_events` history already answers "has this user ever favorited this listing." (b) Emit on every add (no dedup) — rejected by Q3 because repeated toggle-on/off by one interested party would inflate "interest in this listing." (c) A `UNIQUE` partial index on `lead_events (user_id, listing_id) WHERE event_type='favorite_added'` + `ON CONFLICT DO NOTHING` — viable and slightly more concurrency-robust, but adds an index to the high-volume `lead_events` table; the `EXISTS` guard is sufficient at v1 scale and avoids touching Phase 16's table. (Noted as a forward option if favorite write volume ever warrants it.)

---

## R-113 — `v_favorites` SECURITY INVOKER view with an `is_available` flag

**Decision**: The FavoritesPage reads `public.v_favorites`, a `SECURITY INVOKER` view joining `favorites` → `listings` (+ primary price + main image + governorate/city names) that projects the card fields PLUS a computed `is_available = (l.status='approved' AND publish-window)` flag, and does NOT filter on `l.status`.

**Rationale**: FR-025 requires favorites whose listing has left `approved` to still appear, marked "no longer available." `v_listings_public` filters to approved-in-window and would drop them, so the favorites read needs its own view that keeps every favorited row and exposes availability as a flag the UI renders. `SECURITY INVOKER` (the Phase 16 `20260527120013` precedent) makes the base-table self-only RLS apply to view reads, so the view cannot leak another user's favorites. The view projects only public-safe listing columns — never a publisher private field — so reading an unavailable listing's card fields is safe.

**Alternatives considered**: (a) Read `favorites` ids then batch-fetch `v_listings_public` rows in the client — rejected: drops unavailable favorites (the join misses them) and is a two-round-trip read. (b) A SECURITY DEFINER view/function — rejected: SECURITY INVOKER + base RLS is simpler and fail-closed by construction.

---

## R-114 — `favorites` keys and FK delete behaviors

**Decision**: `PRIMARY KEY (user_id, listing_id)`; `user_id → auth.users(id) ON DELETE CASCADE`; `listing_id → public.listings(id) ON DELETE RESTRICT`.

**Rationale**: The composite PK is the FR-007 uniqueness constraint (a user can't double-save) and gives the `add_favorite` RPC a clean `ON CONFLICT (user_id, listing_id) DO NOTHING` idempotency target. `ON DELETE CASCADE` on `user_id` mirrors `user_preferences` (`20260506120003`) — deleting an account removes its favorites, leaving no orphans. `ON DELETE RESTRICT` on `listing_id` matches Phase 16's Q4=C; listings soft-delete via `status='deleted'`, so RESTRICT never fires in normal operation but defends against accidental hard-deletes and preserves the favorite for the "no longer available" indicator.

**Alternatives considered**: A surrogate `id uuid` PK + a separate `UNIQUE (user_id, listing_id)` — rejected: the composite PK is the natural key and avoids a redundant column; `ON DELETE CASCADE` on `listing_id` — rejected (would silently wipe favorites if a listing were ever hard-deleted, and contradicts Q4=C).

---

## R-115 — Entry point = Profile tile; route guards anonymous deep-links

**Decision**: The FavoritesPage is reached via a "My Favorites" `ListTile` on the Profile page (Q1=A), navigating to `/favorites`. The route `redirect`s to `/login` when `AuthBloc.state is Unauthenticated` (deep-link cold-launch hardening).

**Rationale**: The Profile page is already authenticated-only and is the conventional home for personal/account surfaces; favorites are auth-only, so the entry naturally lives there. The redirect protects the deep-link cold-launch case (a shared `/favorites` URL opened while signed-out) by sending the user to login rather than rendering an empty/erroring page.

**Alternatives considered**: Home app-bar heart action — rejected: redundant with the per-card hearts that are the primary save affordance, and the home AppBar already hosts the Phase 16 inquiries action + locale toggle + profile. Bottom-nav tab — rejected: the app has no bottom nav; introducing one is a global navigation change beyond Phase 17's scope.

---

## R-116 — Anonymous heart taps route to sign-in, no pre-auth save

**Decision**: The heart renders for everyone (empty state for anonymous). Tapping while signed-out shows the localized `favorite_sign_in_prompt` and `context.push(AppRoutes.login)`. The listing the anonymous user tapped is NOT auto-saved after they sign in.

**Rationale** (Q2=A): Rendering the heart advertises the feature to anonymous browsers (a sign-up nudge); routing to login on tap is the highest-converting pattern (Aqarmap/Bayut). Not auto-saving avoids a hidden side-effect — the user makes an explicit re-tap after login, which is clearer and avoids surprising saves.

**Alternatives considered**: Hide the heart for anonymous (feature undiscoverable) — rejected. Grey/disable the heart (no path to use it from the tap) — rejected. Auto-save the pre-auth-tapped listing after login — rejected as a hidden side-effect (Principle XII).

---

## R-117 — FavoritesPage cursor pagination

**Decision**: `LoadFavorites` paginates with a cursor on `favorites.created_at DESC` (surfaced as `favorited_at` in `v_favorites`), `limit 30` per page; `FavoritesPageMoreLoaded` extends the cursor.

**Rationale**: FR-027 + the Constitution performance baseline forbid unbounded list queries. Cursor-on-`created_at DESC` matches Phase 13's home-feed convention, so the datasource + bloc reuse a familiar shape, and the `idx_favorites_user_created (user_id, created_at DESC)` index serves it directly.

**Alternatives considered**: Offset pagination — rejected (drift under concurrent inserts); load-all — rejected (unbounded).

---

## R-118 — Shared `FavoriteHeartButton`, not `PropertyCard`

**Decision**: A single shared `FavoriteHeartButton` widget is embedded into the three bespoke live-feed cards (`HomeListingCardTile`, `SearchResultCard`, `MarkerPreviewPopover`) and the `PerListingActionBlock` Favorite CTA.

**Rationale**: Inspection shows the live feed/search/map surfaces render bespoke widgets, NOT the Phase 2 `PropertyCard` — `PropertyCard` (which already has a `favorite`/`onFavoritePressed` heart slot) is used only in `lib/debug/theme_gallery_page.dart`. So the spec's "wire the PropertyCard heart" intent is realized by introducing one shared button widget each bespoke surface hosts, driven by the `FavoritesCubit`. This keeps the toggle behavior, the anonymous-prompt branch, and the token styling in one place rather than duplicated four times.

**Alternatives considered**: (a) Migrate all feeds to `PropertyCard` — rejected: a large refactor of three shipped, visually-tuned surfaces, far beyond Phase 17's scope. (b) Duplicate the heart logic inline in each card — rejected: four copies of the anonymous-aware toggle is a maintenance hazard and a Principle-XII risk (divergent behavior).
