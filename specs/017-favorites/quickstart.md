# Quickstart — Favorites (Phase 17) end-to-end verification

A reviewer/agent validates Phase 17 with this recipe. One step per Success Criterion. Device matrix: reference Infinix Note 8 (primary) + Pixel 8 Pro AVD (secondary), per project QA memory. All `flutter run`/`build` MUST include `--dart-define-from-file=.env.json`.

## 1. Apply migrations (in order)

Apply via Supabase MCP `apply_migration` (or CLI), filename-ascending:

1. `20260529120001_create_favorites_table.sql`
2. `20260529120002_create_favorites_policies.sql`
3. `20260529120003_create_v_favorites_view.sql`
4. `20260529120004_create_add_favorite_rpc.sql`
5. `20260529120005_phase17_advisor_hardening.sql`

Verify: `SELECT to_regclass('public.favorites');`, `SELECT to_regclass('public.v_favorites');`, and `\df public.add_favorite`.

## 2. Fixture data

Ensure ≥ 4 approved listings, ≥ 1 listing that you will flip away from `approved` (for SC-011), and two test users (user-A, user-B). Save at least one listing as BOTH users (for the SC-005 cross-user check).

## 3. Toggle from a card (SC-001) and details (SC-002)

Sign in as user-A. Home feed → tap an empty heart on an approved card. Confirm: heart fills < 300 ms; within 2 s a `public.favorites` row exists (`SELECT * FROM public.favorites WHERE user_id='<A>'`). Open that listing's details → its Favorite CTA is already filled. Tap it → row deleted < 2 s.

## 4. Cross-surface consistency (SC-003)

Save listing-X on the home feed. Without refreshing, navigate to: its details page, the search results (search for it), the map marker preview, and the FavoritesPage. Confirm the heart is filled on every surface.

## 5. FavoritesPage (SC-004, SC-012, SC-015)

Profile → "My Favorites." Confirm: all of user-A's saved listings appear, newest-saved first; no listing A didn't save appears. Inspect the network call — confirm a `LIMIT`/cursor (bounded query, SC-015). Un-save everything → localized empty-state renders (SC-012).

## 6. Cross-user isolation (SC-005, SC-006) — load-bearing

Capture the wire-level response of user-A's favorites query. Confirm only A's rows. Repeat as user-B → only B's rows (even for the listing both saved, each sees only their own row). Repeat anonymous → zero rows / denied. Repeat as an admin/super-admin → only their own rows (no cross-user override). Then via SQL as user-A:

```sql
SELECT count(*) FROM public.favorites WHERE user_id='<B>';                 -- 0
DELETE FROM public.favorites WHERE user_id='<B>' AND listing_id='<l>';     -- 0 rows
-- forged INSERT has no grant path from the client; confirm the client cannot INSERT directly:
INSERT INTO public.favorites(user_id, listing_id) VALUES ('<B>','<l>');    -- denied (no INSERT grant)
```

## 7. Lead-event dedup (SC-007, SC-008)

As a user with no prior favorites: favorite listing-X → exactly one `favorite_added` in `lead_events`. Un-favorite X → no new event. Re-favorite X → still exactly one (dedup). Favorite listing-Y → a second event for (user, Y). As a different user, favorite X → a `favorite_added` for (that user, X). For SC-008, simulate a mid-RPC failure (e.g., a bad `p_listing_id` after a partial state in a test harness) and confirm zero partial states (the favorite + event are atomic).

```sql
SELECT event_type, count(*) FROM public.lead_events
  WHERE user_id='<u>' AND listing_id='<X>' GROUP BY event_type; -- favorite_added | 1
```

## 8. Persistence (SC-009)

Save on device-1; sign in on device-2 (AVD) as the same user → favorites appear. Un-save on device-2; refresh on device-1 → gone. Force-stop/relaunch and uninstall/reinstall on device-1 → favorites persist (server-side state).

## 9. Anonymous path (SC-010)

Sign out. Browse a card / details → heart visible (empty). Tap it → no `favorites` row, no `favorite_added` event; localized "Sign in to save favorites" prompt; routed to `/login`. Sign in → the tapped listing is NOT auto-saved (explicit re-tap required).

## 10. Unavailable favorite (SC-011)

Favorite an approved listing. Flip its status server-side (`UPDATE public.listings SET status='sold' WHERE id='<l>'`). Reload FavoritesPage → the card still appears with the localized "no longer available" indicator; tapping it opens the Phase 13 details page (read-only / not-found state), no crash.

## 11. Theme × locale matrix (SC-013)

On the reference device (480 dp) and a 412 dp AVD, render the FavoritesPage, a card heart, the sign-in prompt, the empty-state, and the unavailable indicator in all four combinations: light/ar, light/en, dark/ar, dark/en. Confirm all strings localized and directionally correct (RTL/LTR).

## 12. Grep gates (SC-014 + Constitution IX, V, VI)

```bash
# a) zero new pubspec deps vs the Phase 16 baseline
git diff origin/main -- pubspec.yaml | grep -E '^\+' | grep -vE '^\+\+\+'   # expect: no new package lines

# b) no hardcoded role/permission branch in favorites code
grep -rniE "role *== *'admin'|view_all|isAdmin|superAdmin" lib/features/favorites/   # expect: none

# c) no Supabase import in domain/ or presentation/ (Constitution IX)
grep -rn "package:supabase_flutter" lib/features/favorites/domain lib/features/favorites/presentation   # expect: none

# d) no inline string literals in new feature widgets (Constitution V)
grep -rnE "Text\('[^']" lib/features/favorites/presentation/   # expect: none (all via AppLocalizations)

# e) no inline hex / raw font-size in favorites widgets (Constitution VI)
grep -rnE "Color\(0xFF|fontSize: *[0-9]" lib/features/favorites/   # expect: none
```

## Final SC matrix

Tick SC-001..SC-015 against §3–§12. Any partial / substitute-device result stays `- [ ]` with a `**⚠️ PARTIAL —**` note per the project's strict-task-completion rule; capture the gap in `DEFERRED.md` if one is opened.
