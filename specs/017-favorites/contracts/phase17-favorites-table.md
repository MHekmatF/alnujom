# Contract — `public.favorites` table

**Migration**: `supabase/migrations/20260529120001_create_favorites_table.sql`
**Spec**: FR-007, FR-010, FR-013. **Decision**: R-114.

## Columns

| Column | Type | Constraints |
|--------|------|-------------|
| `user_id` | `uuid` | NOT NULL; FK → `auth.users(id)` ON DELETE CASCADE |
| `listing_id` | `uuid` | NOT NULL; FK → `public.listings(id)` ON DELETE RESTRICT |
| `created_at` | `timestamptz` | NOT NULL DEFAULT `now()` |

**Primary key**: `(user_id, listing_id)` — uniqueness per FR-007; the `ON CONFLICT` target for the idempotent RPC insert.

**Index**: `idx_favorites_user_created (user_id, created_at DESC)` — FavoritesPage newest-first read.

**RLS**: enabled in this migration; policies in `…120002`.

## Behavioral contract

- A user cannot hold two rows for the same listing (composite PK).
- Deleting an `auth.users` row cascades to that user's favorites (no orphans).
- A `listings` hard-delete is RESTRICTed (listings soft-delete via `status='deleted'`; the favorite survives a status change and surfaces as "no longer available").
- No `updated_at` — favorites are insert/delete-only (nothing to mutate).

## Smoke tests

```sql
-- composite PK rejects a duplicate (as the table owner, bypassing RLS):
INSERT INTO public.favorites(user_id, listing_id) VALUES ('<u>','<l>');
INSERT INTO public.favorites(user_id, listing_id) VALUES ('<u>','<l>'); -- ERROR: duplicate key
-- RESTRICT blocks a listing hard-delete that has a favorite:
DELETE FROM public.listings WHERE id='<l>'; -- ERROR: update or delete violates FK (RESTRICT)
```
