# favorites

## Purpose

`public.favorites` is the Phase 17 private saved-listings store. Each row
records one user's decision to save one listing. The table is strictly
self-only — no publisher, no admin, and no anonymous session can read another
user's favorites (FR-017..FR-019). There is no `favorites.view_all`
permission anywhere in the system.

Authoritative interface contract:
[`specs/017-favorites/contracts/phase17-favorites-table.md`](../../specs/017-favorites/contracts/phase17-favorites-table.md).

## Shape

Defined in `supabase/migrations/20260529120001_create_favorites_table.sql`.
Three columns; direct client writes are blocked at the table level (Migration 2
revokes INSERT/UPDATE) so every row originates from the `add_favorite`
SECURITY DEFINER RPC (Migration 4).

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `user_id` | `uuid` | NOT NULL, FK → `auth.users(id)` ON DELETE CASCADE | Identifies the saving user. Cascade ensures account deletion removes all favorites. |
| `listing_id` | `uuid` | NOT NULL, FK → `public.listings(id)` ON DELETE RESTRICT | Identifies the saved listing. RESTRICT defends against accidental hard-deletes; see FK delete behaviors below. |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Server-generated; drives FavoritesPage newest-first ordering. |

## Composite primary key

`PRIMARY KEY (user_id, listing_id)` — a user cannot hold two rows for the
same listing (FR-007). The composite PK is also the `ON CONFLICT` target for
the idempotent RPC insert: a second call to `add_favorite('<same-listing>')`
after the row already exists is a no-op (`ON CONFLICT DO NOTHING`), so
re-tapping the heart never errors and never emits a duplicate `favorite_added`
lead event.

## FK delete behaviors

| FK column | References | ON DELETE behavior | Rationale |
|-----------|-----------|-------------------|-----------|
| `user_id` | `auth.users(id)` | **CASCADE** | Deleting an account removes its favorites with no orphans. Mirrors the `user_preferences` precedent (`20260506120003`). |
| `listing_id` | `public.listings(id)` | **RESTRICT** (Q4=C) | Listings soft-delete via `status='deleted'`; a hard-delete of a favorited listing is rejected by the DB engine. This preserves the favorite row so the FavoritesPage can show the "no longer available" indicator (FR-025) even after a listing is effectively retired. |

## Index

`idx_favorites_user_created (user_id, created_at DESC)` — covers the
FavoritesPage newest-first query pattern (FR-013 / FR-021 / R-117). Cursor
pagination on `created_at DESC` scans this index directly with no full-table
scan (SC-015).

## RLS posture (forward-stated)

- **Migration 1 (this file)**: `ALTER TABLE public.favorites ENABLE ROW LEVEL
  SECURITY` is set. NO policies are attached. The default-deny posture means
  direct reads from any client session return zero rows.
- **Migration 2 (`20260529120002_create_favorites_policies.sql`)** will add:
  - `favorites_select_self` — SELECT for `authenticated` where
    `user_id = auth.uid()`.
  - `favorites_delete_self` — DELETE for `authenticated` where
    `user_id = auth.uid()` (the un-favorite client path per Q5=A).
  - `REVOKE INSERT, UPDATE ON public.favorites FROM authenticated, anon` —
    no client can insert or mutate a row directly.
  - No `anon` policy — anonymous sessions are denied entirely (FR-018).
  - No admin override policy — there is no `favorites.view_all` permission
    and no admin SELECT path (FR-019).

The self-only RLS boundary is the load-bearing privacy control for
FR-017..FR-019 and SC-005..SC-006.

## Write model

**INSERT**: exclusively via `public.add_favorite(p_listing_id uuid)` (Migration
4, SECURITY DEFINER). No direct INSERT grant is given to `authenticated` or
`anon`. This makes it impossible for a client to create a favorite that
bypasses the co-transactional `favorite_added` lead event (FR-011). The RPC
also validates that the target listing exists and is `status='approved'` before
inserting.

**DELETE**: direct, via the `favorites_delete_self` policy (Migration 2). The
un-favorite path is a plain `DELETE FROM public.favorites WHERE listing_id =
'<id>'` from the authenticated client — no RPC is needed. Removal emits NO
`lead_events` row (FR-016).

**UPDATE**: none. Favorites are insert/delete-only — there is nothing to
mutate.

## `favorite_added` lead event deduplication

The `add_favorite` RPC co-transactionally inserts a `favorite_added` row into
`public.lead_events` on the **first ever** add for a given `(user_id,
listing_id)` pair (Q3=B / FR-015). Subsequent adds — even after an intermediate
removal — are silenced by an `EXISTS` guard against `lead_events` history. This
means the event fires at most once per user per listing, regardless of how many
times the heart is toggled (R-112).

## Failure modes

- Duplicate `(user_id, listing_id)` insert (client path) → blocked by
  Migration 2's `REVOKE INSERT`; RPC path → `ON CONFLICT DO NOTHING`.
- FK violation on `listing_id` (listing does not exist) → SQLSTATE 23503;
  `add_favorite` RPC raises `listing_not_found` before reaching the INSERT.
- FK RESTRICT on listing hard-delete → SQLSTATE 23503; listings soft-delete
  via `status='deleted'` so this should never fire in normal operation.
- Anonymous INSERT/SELECT → denied by RLS default-deny + no `anon` policy.
- Cross-user SELECT (forged `WHERE user_id='<other>'`) → 0 rows (self-only
  RLS; SC-005).
- Cross-user DELETE → 0 rows affected (self-only RLS; SC-006).

## RLS matrix (live — Migration 2)

Migration `20260529120002_create_favorites_policies.sql` attaches the self-only
policies that Migration 1 forward-stated. The policies are the load-bearing
privacy boundary for FR-017..FR-019 and SC-005..SC-006.

| Reader | SELECT | DELETE | INSERT | UPDATE |
|--------|--------|--------|--------|--------|
| Owner (`auth.uid() = user_id`) | own rows only (`favorites_select_self`) | own rows only (`favorites_delete_self`) | denied — no grant; use `add_favorite` RPC | denied — no policy, no grant |
| Other authenticated user | 0 rows | 0 rows affected | denied | denied |
| Anonymous (`anon`) | denied — no `TO anon` policy | denied | denied | denied |
| Admin / super-admin | own rows only — there is **no** `favorites.view_all` and no admin override (FR-019) | own rows only | denied | denied |

Policy definitions:

- `favorites_select_self` — `FOR SELECT TO authenticated USING (user_id = auth.uid())`.
- `favorites_delete_self` — `FOR DELETE TO authenticated USING (user_id = auth.uid())` (the un-favorite client path per Q5=A + FR-012; emits no lead event).
- `REVOKE INSERT, UPDATE ON public.favorites FROM authenticated, anon` — row creation is exclusively via the `add_favorite` SECURITY DEFINER RPC (Migration 4); favorites are insert/delete-only so there is no UPDATE path.
- No `anon` policy and no INSERT policy — anonymous sessions are denied entirely, and even an authenticated client cannot create a row that bypasses the co-transactional `favorite_added` event (FR-011 + FR-017).

## `v_favorites` view + `is_available` contract (Migration 3)

Migration `20260529120003_create_v_favorites_view.sql` defines the FavoritesPage
projection. Key properties:

- **`SECURITY INVOKER`** (`WITH (security_invoker = true)`): the view executes
  with the caller's role, so the base-table `favorites_select_self` RLS applies
  to view reads. A caller sees only their own favorites — verified identical to
  the table-level isolation. (Phase 16 `20260527120013` precedent; the default
  `security_invoker = false` would run as the view owner and bypass RLS.)
- **`GRANT SELECT … TO authenticated`** only — NOT to `anon`.
- **Projects ZERO publisher private fields** — no legal name, national id,
  phone, or whatsapp. Card-safe columns only: `id` (= `favorites.listing_id`),
  `favorited_at` (= `favorites.created_at`), `title`, `property_type`,
  `purpose`, `primary_amount`/`primary_currency` (LATERAL primary price),
  `main_image_path` (LATERAL lowest-ordering image), and the bilingual
  `governorate_name_ar/_en` + `city_name_ar/_en` from the `display_name` JSONB.
- **`is_available` flag** — computed as
  `l.status = 'approved' AND (l.expires_at IS NULL OR l.expires_at > now())`.
- **Does NOT filter on `l.status`** (unlike `v_listings_public`): unavailable
  favorites MUST still appear in the result set with `is_available = false`,
  driving the FavoritesPage "no longer available" indicator (Q4=A + FR-025).
  Flipping a favorited listing away from `approved` therefore keeps its row in
  `v_favorites` with `is_available = false` rather than removing it.
- Read newest-first by `favorited_at DESC`; cursor pagination on `favorited_at`
  (R-117), backed by the `idx_favorites_user_created` index (no full scan,
  SC-015).
