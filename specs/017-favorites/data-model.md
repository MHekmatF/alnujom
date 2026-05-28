# Phase 1 Data Model — Favorites (Phase 17)

Full SQL migration bodies, Dart domain entities, and a per-FR / per-SC verification map. The five migrations land under `supabase/migrations/` with the `20260529` prefix (continuing after Phase 16's `20260527120016`). The IMPLEMENTATION_PLAN's logical name `0026_create_favorites.sql` maps to migration 1 below.

> Apply order (filename ascending): `…120001` (table) → `…120002` (policies) → `…120003` (view) → `…120004` (RPC) → `…120005` (hardening). Migrations 2 and 4 both depend only on 1; 3 depends on 1. There is **no** view→function coupling (the view does not call the RPC), so 3 and 4 are order-independent of each other.

---

## 1. Migration 1 — `20260529120001_create_favorites_table.sql`

```sql
-- Phase 17 (spec/017-favorites) — Migration 1/5
-- public.favorites — a user's private saved listings.
--
-- Privacy: self-only. A row belongs to exactly one user and is readable /
-- deletable only by that user (policies in Migration 2). NO publisher, NO
-- admin, NO anonymous reader path (FR-017..FR-019). There is no
-- favorites.view_all permission anywhere in the system.
--
-- Write model:
--   - INSERT: only via public.add_favorite(uuid) SECURITY DEFINER RPC
--     (Migration 4). No direct client INSERT grant — so a client cannot
--     create a favorite that bypasses the co-transactional favorite_added
--     lead event (FR-011).
--   - DELETE: direct, via the favorites_delete_self self-only policy (Q5=A).
--   - UPDATE: none — favorites are insert/delete-only.
--
-- Keys / FKs:
--   - PRIMARY KEY (user_id, listing_id): a user cannot double-save (FR-007);
--     also the ON CONFLICT target for the idempotent RPC insert.
--   - user_id -> auth.users ON DELETE CASCADE: deleting an account removes
--     its favorites (user_preferences precedent, 20260506120003).
--   - listing_id -> listings ON DELETE RESTRICT (Q4=C): listings soft-delete
--     via status='deleted', so RESTRICT never fires normally; it defends
--     against accidental hard-deletes and preserves the favorite for the
--     "no longer available" FavoritesPage indicator (FR-025).

CREATE TABLE IF NOT EXISTS public.favorites (
  user_id     UUID        NOT NULL REFERENCES auth.users(id)     ON DELETE CASCADE,
  listing_id  UUID        NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, listing_id)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- FavoritesPage newest-first read (FR-013 / FR-021 / R-117).
CREATE INDEX IF NOT EXISTS idx_favorites_user_created
  ON public.favorites (user_id, created_at DESC);
```

---

## 2. Migration 2 — `20260529120002_create_favorites_policies.sql`

```sql
-- Phase 17 — Migration 2/5 — self-only RLS (FR-017, FR-018, Q5=A).

-- SELECT: a user reads only their own favorites.
CREATE POLICY favorites_select_self
  ON public.favorites
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- DELETE: a user removes only their own favorites (the client's un-favorite
-- path per Q5=A + FR-012). Removal emits NO lead event.
CREATE POLICY favorites_delete_self
  ON public.favorites
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- No INSERT policy and no INSERT grant: row creation is exclusively via the
-- add_favorite SECURITY DEFINER RPC (Migration 4). This makes it impossible
-- for a client to create a favorite that bypasses the favorite_added event
-- (FR-011 + FR-017). No UPDATE policy: favorites are insert/delete-only.
REVOKE INSERT, UPDATE ON public.favorites FROM authenticated, anon;

-- Anonymous reads are denied entirely (no policy TO anon; FR-018).
```

---

## 3. Migration 3 — `20260529120003_create_v_favorites_view.sql`

```sql
-- Phase 17 — Migration 3/5 — FavoritesPage projection (R-113).
-- SECURITY INVOKER so the base-table self-only RLS on public.favorites
-- applies to view reads (Phase 16 20260527120013 precedent). Projects only
-- public-safe listing columns — never a publisher private field.
-- Does NOT filter on l.status: unavailable favorites MUST still appear with
-- an is_available=false flag (Q4=A + FR-025).

CREATE OR REPLACE VIEW public.v_favorites
WITH (security_invoker = true) AS
SELECT
  f.listing_id                              AS id,
  f.created_at                              AS favorited_at,
  l.title,
  l.property_type,
  l.purpose,
  lp.amount                                 AS primary_amount,
  lp.currency_code                          AS primary_currency,
  lm.storage_path                           AS main_image_path,
  g.display_name->>'ar'                     AS governorate_name_ar,
  g.display_name->>'en'                     AS governorate_name_en,
  c.display_name->>'ar'                     AS city_name_ar,
  c.display_name->>'en'                     AS city_name_en,
  (l.status = 'approved'
    AND (l.expires_at IS NULL OR l.expires_at > now())) AS is_available
FROM public.favorites f
JOIN public.listings l ON l.id = f.listing_id
LEFT JOIN LATERAL (
  SELECT amount, currency_code
  FROM public.listing_prices
  WHERE listing_id = l.id AND is_primary = true
  LIMIT 1
) lp ON true
LEFT JOIN LATERAL (
  SELECT storage_path
  FROM public.listing_media
  WHERE listing_id = l.id AND kind = 'image'
  ORDER BY ordering ASC
  LIMIT 1
) lm ON true
LEFT JOIN public.governorates g ON g.id = l.governorate_id
LEFT JOIN public.cities       c ON c.id = l.city_id;

GRANT SELECT ON public.v_favorites TO authenticated;
-- NOT granted to anon.
```

---

## 4. Migration 4 — `20260529120004_create_add_favorite_rpc.sql`

```sql
-- Phase 17 — Migration 4/5 — add_favorite write path (FR-011, FR-014, FR-015).
-- SECURITY DEFINER: inserts the favorite AND (deduped) the favorite_added
-- lead event atomically. Authenticated-only. Validates approved listing.

CREATE OR REPLACE FUNCTION public.add_favorite(p_listing_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_status TEXT;
  v_ip     INET;
  v_ua     TEXT;
BEGIN
  -- Favorites are authenticated-only (FR-011).
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000';
  END IF;

  -- Listing must exist and be approved (mirrors record_lead_event).
  SELECT l.status INTO v_status FROM public.listings l WHERE l.id = p_listing_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_status <> 'approved' THEN
    RAISE EXCEPTION 'listing_not_approved' USING ERRCODE = '23514';
  END IF;

  -- Idempotent favorite insert (FR-007 composite PK).
  INSERT INTO public.favorites (user_id, listing_id)
  VALUES (v_uid, p_listing_id)
  ON CONFLICT (user_id, listing_id) DO NOTHING;

  -- Deduped favorite_added: once per (user, listing) ever (Q3=B / FR-015).
  IF NOT EXISTS (
    SELECT 1 FROM public.lead_events
    WHERE user_id = v_uid
      AND listing_id = p_listing_id
      AND event_type = 'favorite_added'
  ) THEN
    v_ip := inet_client_addr();
    BEGIN
      v_ua := current_setting('request.headers', true)::jsonb->>'user-agent';
    EXCEPTION WHEN OTHERS THEN
      v_ua := NULL;
    END;

    INSERT INTO public.lead_events (listing_id, user_id, event_type, metadata, created_at)
    VALUES (
      p_listing_id, v_uid, 'favorite_added',
      jsonb_build_object('ip', v_ip::text, 'user_agent', v_ua),
      now()
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.add_favorite(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_favorite(UUID) TO authenticated;
-- NOT granted to anon (FR-011).
```

---

## 5. Migration 5 — `20260529120005_phase17_advisor_hardening.sql`

```sql
-- Phase 17 — Migration 5/5 — advisor hardening (Phase 16 20260527120012 pattern).
ALTER FUNCTION public.add_favorite(UUID) SET search_path = pg_catalog, public;

-- Safety-net grants (idempotent): only SELECT + DELETE reach the client on the
-- table; INSERT/UPDATE are RPC-only; the view is readable by authenticated.
REVOKE INSERT, UPDATE ON public.favorites FROM authenticated, anon;
GRANT SELECT ON public.v_favorites TO authenticated;

REVOKE ALL ON FUNCTION public.add_favorite(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_favorite(UUID) TO authenticated;
```

---

## 6. Dart domain entities (`lib/features/favorites/domain/entities/`)

```dart
// favorite.dart (Sub-Phase A) — the cross-layer primitive.
class Favorite extends Equatable {
  const Favorite({required this.listingId, required this.createdAt});
  final String listingId;
  final DateTime createdAt;
  @override
  List<Object?> get props => [listingId, createdAt];
}
```

```dart
// favorite_listing.dart (Sub-Phase E) — the FavoritesPage card projection,
// mirroring the v_favorites row shape.
class FavoriteListing extends Equatable {
  const FavoriteListing({
    required this.id,
    required this.title,
    required this.propertyType,   // PropertyType (Phase 10)
    required this.purpose,        // ListingPurpose (Phase 10)
    required this.primaryAmount,
    required this.primaryCurrency,
    required this.mainImagePath,  // String?
    required this.governorateNameAr,
    required this.governorateNameEn,
    required this.cityNameAr,
    required this.cityNameEn,
    required this.isAvailable,    // drives the FR-025 indicator
    required this.favoritedAt,
  });
  // ... fields + props ...
}
```

**`FavoritesRepository`** (`domain/repositories/favorites_repository.dart`):

```dart
abstract interface class FavoritesRepository {
  Future<Result<Unit, Failure>> addFavorite(String listingId);
  Future<Result<Unit, Failure>> removeFavorite(String listingId);
  Future<Result<List<String>, Failure>> loadFavoriteIds();
  Future<Result<List<FavoriteListing>, Failure>> loadFavorites({String? cursor, int limit});
}
```

`Result` + `Failure` come from `lib/core/errors/{result,failure}.dart` (Phase 1). `PropertyType` + `ListingPurpose` come from `lib/features/listing_form/domain/entities/listing.dart` (Phase 10). No Supabase type appears in `domain/`.

---

## 7. Per-FR verification map

| FR | Where satisfied |
|----|-----------------|
| FR-001 | Sub-Phase H1 — `PerListingActionBlock` Favorite CTA rewired; Share/Report untouched |
| FR-002 | Sub-Phase H2/H3/H4 — `FavoriteHeartButton` embedded in `HomeListingCardTile`, `SearchResultCard`, `MarkerPreviewPopover` |
| FR-003 / FR-004 | `add_favorite` RPC insert (Migration 4) / self-only DELETE (Migration 2) via `FavoritesCubit.toggle` |
| FR-005 | `FavoritesCubit` session `Set<String>` + `BlocSelector` hearts (R-110) |
| FR-006 | `FavoritesCubit.toggle` optimistic + revert-on-failure (Sub-Phase F) |
| FR-007 | Composite PK `(user_id, listing_id)` + `ON CONFLICT DO NOTHING` |
| FR-008 / FR-009 | `FavoriteHeartButton` renders for all; anonymous tap → prompt + `/login`, no pre-auth save (R-116) |
| FR-010 | Migration 1 — `favorites` table + FKs + PK + index |
| FR-011 | `add_favorite` RPC (auth-required, approved-only, no client INSERT grant) |
| FR-012 | `favorites_delete_self` policy (Migration 2) — no `remove_favorite` RPC |
| FR-013 | `idx_favorites_user_created` |
| FR-014 / FR-015 | RPC co-transactional + `EXISTS`-dedup against `lead_events` (Migration 4) |
| FR-016 | Removal path emits no event; no `lead_events` schema change |
| FR-017 / FR-018 | Self-only SELECT/DELETE policies; no anon policy (Migration 2) |
| FR-019 | No `favorites.view_all` permission introduced anywhere |
| FR-020 | `lib/features/favorites/` Clean Architecture layout |
| FR-021 / FR-027 | `v_favorites` newest-first + cursor pagination (R-113 / R-117) |
| FR-022 | Profile "My Favorites" tile → `/favorites` (Sub-Phase H5) |
| FR-023 | FavoritesPage card tap → `/listings/:id` (available + unavailable, Q4=A) |
| FR-024 | FavoritesPage heart = same `FavoritesCubit.toggle` path |
| FR-025 | `v_favorites.is_available` flag + `favorite_unavailable_indicator` |
| FR-026 | `FavoritesEmptyState` widget |
| FR-028 / FR-029 | ARB keys (Sub-Phase G) + Phase 2 tokens, RTL/LTR + light/dark |
| FR-030 | Zero new pubspec deps (R-109) |
| FR-031 | RLS + no service-role key + SECURITY DEFINER RPC for the event write |
| FR-032 | No role/permission branch in favorites code |
| FR-033 | Share/Report stubs + `lead_events` schema untouched |

## 8. Per-SC verification map

| SC | Verified by (see quickstart.md) |
|----|--------------------------------|
| SC-001 / SC-002 | Heart fill/empty ≤300 ms optimistic + row written/deleted ≤2 s (timed on reference device) |
| SC-003 | Save on home → filled on details/search/map/FavoritesPage with no refresh |
| SC-004 | FavoritesPage lists exactly the user's saved set, newest-first |
| SC-005 | Two-user wire-level capture: user-A query returns only A's rows; anon → 0; admin → only own |
| SC-006 | Forged-`user_id` INSERT rejected (no grant); DELETE of another user's row → 0 rows |
| SC-007 | `lead_events` inspection: first-add emits one; un-favorite emits none; re-add emits none; new listing/user emits one |
| SC-008 | Simulated mid-transaction failure → zero partial states (RPC atomicity) |
| SC-009 | Persist across restart / reinstall / second device |
| SC-010 | Anonymous heart visible; tap → 0 rows / 0 events + sign-in prompt → `/login` |
| SC-011 | Favorite an approved listing, flip its status, reload → "no longer available" indicator, no crash |
| SC-012 | Zero-favorites account → empty-state |
| SC-013 | Four-combination (light/dark × ar/en) render check |
| SC-014 | Grep: zero new pubspec deps; zero hardcoded role branches in `lib/features/favorites/` |
| SC-015 | FavoritesPage query carries `LIMIT`/cursor; no unbounded scan |
