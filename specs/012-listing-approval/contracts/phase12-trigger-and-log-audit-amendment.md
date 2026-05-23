# Contract: FR-024 Trigger + `log_audit()` Amendment

**Migration**: `supabase/migrations/20260523120004_amend_phase10_phase4_triggers_for_session_var.sql`
**Implements**: FR-024 (mandatory amendment), R-43 (session-variable design), R-49 (function name audit)
**Verifies**: SC-005, SC-030, SC-031

## Functions modified (3 amendments + 2 new setters = 5 CREATE OR REPLACE statements)

### 1. `public.set_app_user_id_for_session(user_id UUID) RETURNS void` — NEW

SECURITY DEFINER. Sets the transaction-scoped session variable `app.current_user_id`. Granted EXECUTE to `service_role` ONLY.

### 2. `public.set_app_rejection_reason_for_session(reason_json TEXT) RETURNS void` — NEW

SECURITY DEFINER. Sets `app.current_rejection_reason`. Granted to `service_role` ONLY.

### 3. `public.listing_status_transition_trigger_fn() RETURNS TRIGGER` — AMENDED

Phase 10's body unchanged EXCEPT:
- `changed_by` column expression: `auth.uid()` → `coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid())`
- `reason` column expression: hardcoded `NULL` → `nullif(current_setting('app.current_rejection_reason', true), '')`

Behavior matrix per data-model.md §1.2.

### 4. `public.listings_audit_trigger_fn() RETURNS TRIGGER` — AMENDED

Phase 10's body unchanged EXCEPT every `INSERT INTO audit_logs (...) VALUES (auth.uid(), ...)` becomes `VALUES (coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()), ...)`. The function's six action keys (`listing.created`, `listing.updated`, `listing.approved`, `listing.rejected`, `listing.paused`, `listing.deleted`) and JSONB before/after shapes are preserved verbatim.

### 5. `public.log_audit() RETURNS TRIGGER` — AMENDED

Phase 4's body unchanged EXCEPT the single INSERT statement's `actor_user_id` source. R-05 narrow relaxation. Phase 5–11 callers continue to attribute correctly because the COALESCE falls back to `auth.uid()`.

## File immutability invariants

Phase 4's `supabase/migrations/20260506120004_create_audit_logs.sql` and Phase 10's `supabase/migrations/20260519120006_create_listing_status_history.sql` remain UNEDITED. The amendments live exclusively in Phase 12's new migration. Verified by `git diff` against the prior commit.

## Verification post-apply

```sql
-- All 5 functions present with the new bodies:
SELECT proname FROM pg_proc WHERE pronamespace='public'::regnamespace
  AND proname IN ('set_app_user_id_for_session',
                  'set_app_rejection_reason_for_session',
                  'listing_status_transition_trigger_fn',
                  'listings_audit_trigger_fn',
                  'log_audit');
-- Expected: 5 rows.

-- All 3 amended trigger functions contain the COALESCE expression:
SELECT proname,
       position('coalesce(nullif(current_setting(''app.current_user_id''' IN pg_get_functiondef(oid)) > 0 AS has_actor_coalesce
FROM pg_proc WHERE pronamespace='public'::regnamespace
  AND proname IN ('listing_status_transition_trigger_fn', 'listings_audit_trigger_fn', 'log_audit');
-- Expected: 3 rows, all has_actor_coalesce = true.

-- Verify session-var setter grants:
SELECT proname, proacl FROM pg_proc
WHERE proname IN ('set_app_user_id_for_session', 'set_app_rejection_reason_for_session');
-- Expected: proacl contains 'service_role=X' (EXECUTE).
```
