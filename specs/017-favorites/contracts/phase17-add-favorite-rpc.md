# Contract — `public.add_favorite(uuid)` RPC

**Migration**: `supabase/migrations/20260529120004_create_add_favorite_rpc.sql`
**Spec**: FR-007, FR-011, FR-014, FR-015. **Decisions**: R-111, R-112.

## Signature

```sql
public.add_favorite(p_listing_id uuid) RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
```

**Grant**: `EXECUTE TO authenticated` only (NOT `anon` — FR-011).

## Behavior (in one transaction)

1. `auth.uid()` NULL → `RAISE 'auth_required'` (ERRCODE `28000`).
2. Listing missing → `RAISE 'listing_not_found'` (`23503`); status ≠ `approved` → `RAISE 'listing_not_approved'` (`23514`).
3. `INSERT INTO favorites (user_id, listing_id) VALUES (auth.uid(), p_listing_id) ON CONFLICT (user_id, listing_id) DO NOTHING` — idempotent (FR-007).
4. Dedup gate (Q3=B / FR-015): if NO `favorite_added` `lead_events` row exists for `(auth.uid(), p_listing_id)`, INSERT one with `metadata = {ip, user_agent}` captured from the trusted server context. Otherwise skip the event.

Both inserts share the function's transaction → atomic (FR-014). Removal is NOT here — it is the `favorites_delete_self` DELETE policy (no event).

## Error codes (client maps to localized messages)

| Code | Meaning |
|------|---------|
| `auth_required` (28000) | anonymous caller — client should route to `/login` (defense-in-depth; the UI also pre-checks) |
| `listing_not_found` (23503) | bad `p_listing_id` |
| `listing_not_approved` (23514) | listing not in `approved` status |

## Smoke tests

```sql
-- first add emits exactly one favorite_added:
SELECT public.add_favorite('<approved-l>');
SELECT count(*) FROM public.lead_events
  WHERE user_id=auth.uid() AND listing_id='<approved-l>' AND event_type='favorite_added'; -- 1
-- remove then re-add: still exactly one favorite_added (dedup):
DELETE FROM public.favorites WHERE listing_id='<approved-l>';
SELECT public.add_favorite('<approved-l>');
SELECT count(*) FROM public.lead_events
  WHERE user_id=auth.uid() AND listing_id='<approved-l>' AND event_type='favorite_added'; -- still 1
-- non-approved listing rejected:
SELECT public.add_favorite('<pending-l>'); -- ERROR listing_not_approved
```
