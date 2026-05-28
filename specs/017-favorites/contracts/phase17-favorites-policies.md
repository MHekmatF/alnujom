# Contract — `public.favorites` RLS policies

**Migration**: `supabase/migrations/20260529120002_create_favorites_policies.sql`
**Spec**: FR-011, FR-012, FR-017, FR-018, FR-019. **Decision**: R-111 (Q5=A).

## Policies

| Name | Command | Role | USING | WITH CHECK |
|------|---------|------|-------|-----------|
| `favorites_select_self` | SELECT | authenticated | `user_id = auth.uid()` | — |
| `favorites_delete_self` | DELETE | authenticated | `user_id = auth.uid()` | — |

- **No INSERT policy / no INSERT grant** — `REVOKE INSERT ON public.favorites FROM authenticated, anon`. Row creation is exclusively via `public.add_favorite(uuid)` (SECURITY DEFINER). This makes it physically impossible for a client to create a favorite that bypasses the co-transactional `favorite_added` event.
- **No UPDATE policy** — favorites are insert/delete-only.
- **No `anon` policy** — anonymous reads/writes are denied entirely.

## Behavioral contract (the load-bearing privacy check)

| Reader | Result |
|--------|--------|
| Owner (`auth.uid() = user_id`) | sees / deletes only their own rows |
| Other authenticated user | zero rows on SELECT; zero rows affected on DELETE |
| Anonymous | denied (no policy) |
| Admin / super-admin | sees only their OWN favorites — there is no `favorites.view_all` and no admin override (FR-019) |

## Smoke tests (run as two distinct JWT sessions)

```sql
-- as user-A (forged predicate must not leak user-B):
SELECT count(*) FROM public.favorites WHERE user_id = '<user-B-id>'; -- 0
-- as user-A, attempt to delete user-B's row:
DELETE FROM public.favorites WHERE user_id='<user-B-id>' AND listing_id='<l>'; -- 0 rows
-- as anon:
SELECT count(*) FROM public.favorites; -- denied / 0
```
