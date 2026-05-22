# Contract: Phase 10 Audit Triggers (`listings_audit_trigger`)

**Owner**: Phase 10, migration `20260519120006_create_listing_status_history.sql`.
**Consumers**: Phase 6 audit-log query surfaces (`audit_logs.view` permission); Phase 20 admin dashboard.

## Obligations

Phase 10 attaches one audit trigger group on `public.listings` reusing Phase 4's `log_audit()` function unchanged (R-05 invariant preserved a **seventh** time across Phases 4/5/6/7/8/9/10).

The audit-trigger function `public.listings_audit_trigger_fn()` emits:

| Operation | Status delta | Action keys emitted | Audit rows per op |
|---|---|---|---|
| INSERT | n/a | `listing.created` | 1 |
| UPDATE | no status change | `listing.updated` | 1 |
| UPDATE | status changed → `pending_review` | `listing.updated` + `listing.submitted` | 2 |
| UPDATE | status changed → `approved`        | `listing.updated` + `listing.approved` | 2 |
| UPDATE | status changed → `rejected`        | `listing.updated` + `listing.rejected` | 2 |
| UPDATE | status changed → `paused`          | `listing.updated` + `listing.paused`   | 2 |
| UPDATE | status changed → `expired`         | `listing.updated` + `listing.expired`  | 2 |
| UPDATE | status changed → `sold`            | `listing.updated` + `listing.sold`     | 2 |
| UPDATE | status changed → `rented`          | `listing.updated` + `listing.rented`   | 2 |
| UPDATE | status changed → `deleted`         | `listing.updated` + `listing.deleted`  | 2 |
| DELETE | n/a | `listing.deleted` | 1 |

The `actor_user_id` field is set to `auth.uid()` or NULL when called from a system context. `target_id` is `NEW.id::text` (or `OLD.id::text` for DELETE). `before_state` / `after_state` carry the row JSON via `to_jsonb(...)`.

The trigger function lives in migration 6; the actual `log_audit()` body lives in Phase 4 and is NOT modified.

## Verification

```sql
-- Trigger exists
SELECT tgname FROM pg_trigger WHERE tgrelid='public.listings'::regclass AND tgname='listings_audit_trigger';
-- Expected: 1 row

-- log_audit unchanged
SELECT prosrc FROM pg_proc WHERE proname='log_audit';
-- Expected: identical body to Phase 4 migration

-- After a full create → submit → admin-approve sequence on a single listing:
SELECT action, count(*) FROM public.audit_logs WHERE target_id=<listing_id::text> GROUP BY action ORDER BY action;
-- Expected: listing.created=1, listing.updated=2 (one per status flip), listing.submitted=1, listing.approved=1
```

## Forbidden

- Modifying `public.log_audit()` (R-05 invariant; preserved a 7th time).
- Skipping the `listing.updated` emission on status-change UPDATEs (every UPDATE emits `listing.updated` AND the status-delta verb).
- Emitting `listing.created` on resubmit (resubmit is an UPDATE of `status`, not an INSERT).
