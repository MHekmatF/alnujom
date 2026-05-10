# Contract: Account-Approval Auto-Population Trigger

**Owner**: Phase 5 (`supabase/migrations/20260510120001_create_account_approval_requests.sql` defines the function and trigger).
**Consumers**: Phase 5's auth flow (registration assumes one `account_approval_requests` row exists immediately after signup); Phase 5's admin queue (assumes every registered-but-not-yet-reviewed user has a pending request); Phase 7+ super-admin UI (will reuse the assumption).
**Stability**: Stable across Phase 5 and Phase 6. Phase 7 may extend (not replace) the trigger if a "reopen rejection" path needs to insert a second request row per user — when that happens, the `UNIQUE (user_id)` constraint relaxes to a partial unique index `WHERE status = 'pending'`, but this trigger's "fire on profiles insert" semantic stays.

---

## Purpose

Whenever a row is inserted into `profiles` (which happens transitively whenever an `auth.users` row is inserted, via Phase 4's auto-provision trigger), exactly one matching `account_approval_requests` row appears with `status = 'pending'`. The flow is: `auth.users INSERT` → Phase 4 trigger creates `profiles` row → Phase 5 trigger creates `account_approval_requests` row.

## Function

```
auto_create_account_approval_request() RETURNS TRIGGER
```

- **Language**: PL/pgSQL
- **Security**: `SECURITY DEFINER`
- **search_path**: `SET search_path = public`
- **Trigger event**: `AFTER INSERT ON profiles FOR EACH ROW`

## Side effects

For each `profiles` insert (`NEW.user_id` available):

```sql
INSERT INTO account_approval_requests (user_id, status)
VALUES (NEW.user_id, 'pending')
ON CONFLICT (user_id) DO NOTHING;
```

## Invariants

- For every `profiles` row that exists, there is **exactly one** `account_approval_requests` row whose `user_id` matches. Because Phase 4 guarantees a 1:1 between `auth.users` and `profiles`, this transitively yields a 1:1 between `auth.users` and `account_approval_requests`.
- A retried profile insert (impossible via Phase 4's `ON CONFLICT (user_id) DO NOTHING` on `profiles`, but defensible against future drift) does NOT produce duplicate request rows. The `ON CONFLICT (user_id) DO NOTHING` clause absorbs the retry.
- The request row's `status` is `pending` at creation; subsequent transitions go through `approve_account_approval_request` / `reject_account_approval_request` RPCs, never via direct INSERT.
- The request row's `id` is a fresh UUID — there is no relationship between the `auth.users.id` / `profiles.user_id` and the request row's PK.

## Default values written

| Column | Default written |
|---|---|
| `id` | `gen_random_uuid()` (column default) |
| `user_id` | `NEW.user_id` from the `profiles` insert |
| `status` | `'pending'` (explicit in the INSERT) |
| `rejection_reason` | NULL (column default + CHECK constraint allows NULL when status='pending') |
| `reviewed_by` | NULL (CHECK constraint requires NULL when status='pending') |
| `reviewed_at` | NULL (CHECK constraint requires NULL when status='pending') |
| `created_at` | `now()` (column default) |
| `updated_at` | `now()` (column default; maintained by `set_updated_at` trigger on subsequent UPDATEs) |

## Idempotency

- **Migration**: `CREATE OR REPLACE FUNCTION` + `DROP TRIGGER IF EXISTS … CREATE TRIGGER …` makes re-application safe.
- **Runtime**: `ON CONFLICT (user_id) DO NOTHING` absorbs concurrent or retried inserts.

## Verification (manual SQL via Supabase MCP `execute_sql`)

After applying `20260510120001_create_account_approval_requests.sql`:

```sql
-- 1. Confirm the function exists.
SELECT proname FROM pg_proc WHERE proname = 'auto_create_account_approval_request';

-- 2. Confirm the trigger exists and points at the right function.
SELECT tgname, tgrelid::regclass, tgfoid::regprocedure
FROM pg_trigger
WHERE tgname = 'trg_profiles_auto_create_account_approval_request';

-- 3. Insert a fixture auth.users row, observe the chain.
-- (Done in quickstart.md Step 5 against a fresh test user.)
```

## Privileged-bypass / RLS interaction

- The trigger function is `SECURITY DEFINER`, so it runs as the owner (`postgres`) regardless of which role triggered the parent `INSERT INTO profiles`. This bypasses any RLS or policy gating on `account_approval_requests` for the INSERT path — by design, since the policy file (§1.10 of `data-model.md`) declares NO INSERT policy.
- Self-RLS-read on the resulting row works for the user themselves on subsequent `SELECT` (the policy `account_approval_requests_self_read` matches `user_id = auth.uid()`).

## Failure modes

- **`profiles` insert succeeds but the `account_approval_requests` insert fails**: rolled back via the same statement-level transaction. The originating `auth.users` insert (which transitively triggered the chain) also rolls back, so no half-state user is left behind. (This propagates because Phase 4's auto-provision trigger is `AFTER INSERT ON auth.users` and any exception inside an `AFTER` trigger rolls the whole row's insert.)
- **`account_approval_requests` row already exists for `user_id`** (e.g., a manual fixture inserted one): `ON CONFLICT DO NOTHING` skips, no error.
