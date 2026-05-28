# Contract — `public.v_inquiries_inbox` view

**Owner**: Sub-Phase C (`supabase/migrations/20260527120007_create_v_inquiries_inbox_view.sql`).

**Consumers**: Sub-Phase E `SupabaseInquiriesDatasource.loadInbox` and `.loadDetail`; the publisher inbox + per-inquiry detail + admin oversight surfaces all read from this view.

## Projection (frozen surface)

```sql
SELECT
  i.id,
  i.listing_id,
  l.title             AS listing_title,
  l.status            AS listing_status,
  i.sender_user_id,
  i.sender_name,
  i.message,
  i.status,
  i.created_at,
  i.updated_at,
  public.decrypt_inquirer_phone(i.id) AS inquirer_phone_decrypted
FROM public.inquiries i
JOIN public.listings  l ON l.id = i.listing_id;
```

The `inquirer_phone_decrypted` column is computed per-row by the SECURITY DEFINER `decrypt_inquirer_phone` function which self-gates per the three-tier rule — unauthorized callers see NULL in that column even if the row is otherwise visible to them via the inquiries RLS policies.

`GRANT SELECT ON public.v_inquiries_inbox TO authenticated`. NOT granted to `anon`.

## RLS inheritance

The view does NOT specify `SECURITY INVOKER` or `SECURITY DEFINER` explicitly; Postgres 15's default is invoker semantics, which means the underlying `public.inquiries` table's RLS policies apply to view reads. The result: a publisher sees only their listings' inquiries; a sender sees only their own outbound; an admin with `inquiries.view_all` sees everything.

## Pagination contract

Phase 16 consumers paginate by cursor on `(created_at DESC, id DESC)` per R-104. The data source's `loadInbox(cursor, limit)` issues:

```sql
SELECT * FROM public.v_inquiries_inbox
WHERE (created_at, id) < ($cursor_created_at, $cursor_id)
  AND ($status_filter IS NULL OR status = $status_filter)
  AND ($listing_filter IS NULL OR listing_id = $listing_filter)
ORDER BY created_at DESC, id DESC
LIMIT $limit;
```

## Pre-conditions

- `public.inquiries` table exists.
- `public.decrypt_inquirer_phone(uuid)` function exists (Sub-Phase D).
- `public.listings` exists.

## Post-conditions

- Anonymous reads return zero rows (no GRANT).
- Authorized reads return all columns including `inquirer_phone_decrypted` (NULL when decrypt-gate denies).

## Stability surface

**Frozen**: column names + types in the projection above.

**Allowed**: additional columns in future phases (e.g., a `is_starred` field if a future spec adds favorites for the publisher's CRM).
