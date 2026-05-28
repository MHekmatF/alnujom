# Contract — `public.v_favorites` view

**Migration**: `supabase/migrations/20260529120003_create_v_favorites_view.sql`
**Spec**: FR-021, FR-025, FR-027. **Decision**: R-113.

## Shape

`SECURITY INVOKER` view (base-table self-only RLS applies to view reads). One row per `public.favorites` row for the calling user. Projection:

| Output column | Source |
|---------------|--------|
| `id` | `favorites.listing_id` |
| `favorited_at` | `favorites.created_at` |
| `title`, `property_type`, `purpose` | `listings` |
| `primary_amount`, `primary_currency` | LATERAL `listing_prices WHERE is_primary` |
| `main_image_path` | LATERAL `listing_media WHERE kind='image' ORDER BY ordering LIMIT 1` |
| `governorate_name_ar/_en`, `city_name_ar/_en` | `governorates`/`cities` `display_name` JSONB |
| `is_available` | `l.status='approved' AND (l.expires_at IS NULL OR l.expires_at > now())` |

**Critical**: the view does **NOT** filter on `l.status` (unlike `v_listings_public`). Unavailable favorites MUST still appear; `is_available=false` drives the "no longer available" indicator (Q4=A + FR-025).

**Grant**: `SELECT TO authenticated`. NOT to `anon`.

## Behavioral contract

- Returns only the caller's favorites (SECURITY INVOKER + base RLS) — verified identical to the table-level isolation.
- Projects ZERO publisher private fields (no legal name, national id, phone, whatsapp).
- Read newest-first by `favorited_at DESC`; cursor pagination on `favorited_at` (R-117).

## Smoke tests

```sql
-- as user-A: only A's favorites, both available and unavailable, appear:
SELECT id, is_available FROM public.v_favorites ORDER BY favorited_at DESC;
-- flip a favorited listing away from approved, confirm it still appears is_available=false:
UPDATE public.listings SET status='sold' WHERE id='<favorited-l>';
SELECT id, is_available FROM public.v_favorites WHERE id='<favorited-l>'; -- is_available=false, row present
```
