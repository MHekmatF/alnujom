# Contract: `admin_dashboard_counts()` RPC (Phase 20)

**Type**: Postgres `SECURITY DEFINER` function, callable by the Flutter client via `supabase.rpc('admin_dashboard_counts')`.
**Created by**: P1 — `supabase/migrations/20260601120001_create_admin_dashboard_counts.sql`.
**Consumed by**: P4 — `lib/features/admin/dashboard/data/datasources/` (runtime, string-keyed; not a Dart import).

## Signature

```
admin_dashboard_counts() RETURNS TABLE (
  pending_users     BIGINT,   -- NULL if caller lacks users.view AND users.approve
  pending_listings  BIGINT,   -- NULL if caller lacks listings.view_all AND listings.approve
  open_reports      BIGINT,   -- NULL if caller lacks reports.manage
  new_inquiries_24h BIGINT,   -- NULL if caller lacks inquiries.view_all
  active_listings   BIGINT    -- NULL if caller lacks listings.view_all AND listings.approve
)
```

Returns exactly one row. Each column is `NULL` when the caller is not permitted to see that counter (the client omits a `NULL` counter; a `0` is a real count and is rendered).

## Permission gate (checks at both ends)

- **Backend**: each counter wrapped in `CASE WHEN current_user_has_permission(<key>) THEN (count…) ELSE NULL END`. `REVOKE EXECUTE FROM PUBLIC, anon; GRANT EXECUTE TO authenticated`.
- **Frontend**: the matching tile is hidden by `PermissionChecker.has/any` so an unpermitted user never sees the tile or requests its meaning. The backend gate is authoritative.

## Counter definitions

| Column | Predicate | Gate (any-of) |
|--------|-----------|---------------|
| `pending_users` | `account_approval_requests.status = 'pending'` (column is `status`, an `account_approval_status` enum — NOT `decision`) | `users.view`, `users.approve` |
| `pending_listings` | `listings.status = 'pending_review'` | `listings.view_all`, `listings.approve` |
| `open_reports` | `reports.status IN ('new','reviewing')` | `reports.manage` |
| `new_inquiries_24h` | `inquiries.created_at >= now() - interval '24 hours'` | `inquiries.view_all` |
| `active_listings` | `listings.status = 'approved'` AND in publish window | `listings.view_all`, `listings.approve` |

## Error / edge behavior

- **anon caller**: `EXECUTE` denied (no grant) → client treats as no-counts (the dashboard route is already guarded for non-admins).
- **authenticated, zero permissions**: all columns `NULL` (the user would not reach the dashboard anyway — `authRedirect` over `adminCategoryKeys`).
- **partial permissions**: only permitted columns are non-`NULL`.

## Acceptance checks

1. From a super-admin session, `select * from admin_dashboard_counts();` returns all five non-NULL and equal to the fixture counts (SC-003).
2. From a session WITHOUT `reports.manage`, `open_reports` is `NULL` while permitted counters are non-NULL (SC-004).
3. From an `anon` key, the `rpc` call is rejected (SC-002).
4. Function body is a single statement (one `RETURN QUERY`) — no per-tile client calls (SC-008).
