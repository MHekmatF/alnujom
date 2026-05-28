# Contract — `get_inbox_unread_count()` RPC

**Owner**: Sub-Phase D (`supabase/migrations/20260527120011_create_get_inbox_unread_count_rpc.sql`).

**Consumers**: Sub-Phase F `InquiriesUnreadCubit.refresh()`; Sub-Phase H home AppBar action badge.

## Signature

```sql
public.get_inbox_unread_count() RETURNS INTEGER
LANGUAGE sql SECURITY DEFINER
SET search_path = pg_catalog, public
STABLE
AS $$
  SELECT COUNT(*)::INTEGER
  FROM public.inquiries i
  JOIN public.listings  l ON l.id = i.listing_id
  WHERE l.publisher_user_id = auth.uid()
    AND i.status = 'new';
$$;
```

GRANT EXECUTE TO `authenticated`. NOT granted to `anon` (anonymous users have no inbox).

## Behavior

Returns the count of inquiries whose `status='new'` on every listing the calling publisher owns. The query uses `idx_inquiries_listing_status` partial index (which includes `status IN ('new','seen','responded')`) for index-only execution.

## Pre-conditions

- `public.inquiries` and `public.listings` exist.
- Caller is authenticated (otherwise GRANT denies access).

## Post-conditions

- Returns 0 for users who own no approved listings OR own listings with no `new` inquiries.
- Returns a positive integer for publishers with pending inbox items.
- Execution time < 10ms at 100k-inquiry catalog scale (index-only scan).

## Stability surface

**Frozen**: no parameters, returns `INTEGER`.

**Allowed**: future phases may introduce sibling RPCs (e.g., `get_inbox_total_count()`, `get_inbox_responded_count()`) but MUST NOT change this one's signature.
