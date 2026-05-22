# Contract: `listing_status_transition_trigger`

**Owner**: Phase 10, migration `20260519120006_create_listing_status_history.sql`.
**Consumers**: Phase 12 (approve/reject — relies on the trigger to write history); Phase 10 `MyListingsPage` (reads the most-recent history row for rejection-reason rendering); admin compliance queries.

## Obligations

The trigger fires `AFTER INSERT` and `AFTER UPDATE OF status` on `public.listings` and appends exactly one row to `public.listing_status_history` per fire.

1. On INSERT: appends a row with `previous_status=NULL`, `new_status=NEW.status`, `changed_by=auth.uid()` (or NULL when no JWT), `reason=NULL`.
2. On UPDATE OF status (where `OLD.status IS DISTINCT FROM NEW.status`): appends a row with `previous_status=OLD.status`, `new_status=NEW.status`, `changed_by=auth.uid()`, `reason=NULL`.
3. UPDATEs that do NOT change `status` do NOT fire the trigger (per the `OF status` clause + the IS DISTINCT FROM check).
4. The trigger body uses the `pg_trigger_depth() > 0` predicate path via direct INSERT (the INSERT policy on `listing_status_history` admits inserts only from within a trigger context per R-09 / FR-007).
5. The trigger function lives at `public.listing_status_transition_trigger_fn()` and the trigger at `listing_status_transition_trigger` on `public.listings`.

## Verification

```sql
-- Trigger exists
SELECT tgname FROM pg_trigger WHERE tgrelid = 'public.listings'::regclass AND tgname='listing_status_transition_trigger';
-- Expected: 1 row

-- Function exists
SELECT proname FROM pg_proc WHERE proname='listing_status_transition_trigger_fn';
-- Expected: 1 row

-- After create + submit a draft:
SELECT count(*) FROM public.listing_status_history WHERE listing_id=<id>;
-- Expected: 2 (NULL→draft, draft→pending_review)

-- After updating a non-status field:
UPDATE public.listings SET title='new title' WHERE id=<id>;
SELECT count(*) FROM public.listing_status_history WHERE listing_id=<id>;
-- Expected: 2 (unchanged; trigger did not fire)
```

## Forbidden

- Bypassing the trigger via direct `listing_status_history` INSERT from outside a trigger context (RLS blocks this via `pg_trigger_depth() > 0`).
- Updating the trigger to NOT fire on system-driven status flips (every status change must be recorded).
- Coupling the operational history table to the audit-log table (R-09 separation).
- Setting `reason` from this trigger (Phase 12's approve/reject path sets the reason via a separate write path).
