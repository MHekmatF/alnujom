# audit_logs

## Purpose

`audit_logs` is the append-only audit table for sensitive backend mutations. It
stores actor, action key, target identity, and before/after state snapshots for
audited changes.

## Columns

Defined in `supabase/migrations/20260506120004_create_audit_logs.sql`:

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `UUID` | NO | `gen_random_uuid()` | PK |
| `actor_user_id` | `UUID` | YES | `NULL` | FK to `auth.users(id)`, `ON DELETE SET NULL` |
| `action` | `TEXT` | NO | — | Action key, e.g. `profile.status_changed` |
| `target_type` | `TEXT` | NO | — | Target table/type |
| `target_id` | `TEXT` | YES | `NULL` | PK value resolved by trigger args |
| `before_state` | `JSONB` | YES | `NULL` | Pre-change snapshot |
| `after_state` | `JSONB` | YES | `NULL` | Post-change snapshot |
| `ip` | `INET` | YES | `NULL` | Trigger-context writes keep NULL in Phase 4 |
| `user_agent` | `TEXT` | YES | `NULL` | Trigger-context writes keep NULL in Phase 4 |
| `created_at` | `TIMESTAMPTZ` | NO | `now()` | Insert timestamp |

## `log_audit()` Trigger Function Contract

`log_audit()` is reusable and table-agnostic. Trigger configuration is passed via
`TG_ARGV`:

- `TG_ARGV[0]`: action key
- `TG_ARGV[1]`: captured column list (`*` for all)
- `TG_ARGV[2]`: PK column name (defaults to `id`)

The function resolves `target_id` using `TG_ARGV[2]` and filters update noise via
an `IS DISTINCT FROM` check over configured columns.

Contract reference:
`../../specs/004-supabase-foundation/contracts/log-audit-trigger-fn.md`.

## RLS Posture

RLS is enabled and Phase 4 applies one policy:

- `audit_logs_select_admin` (`TO authenticated`, gated by
  `current_user_is_admin()`)

No INSERT/UPDATE/DELETE client policies are defined. Writes occur through
`SECURITY DEFINER` server-side paths (trigger function).

## Later-Phase Reuse

Later phases attach the same `log_audit()` function to additional tables by adding
new triggers and appropriate `TG_ARGV` values (action key, column list, PK column):

- Phase 5: `account_approval_requests` ✅ **Shipped** in
  `20260510120005_attach_audit_trigger_account_approval_requests.sql` with
  `TG_ARGV = ('account_approval.status_changed',
  'status,rejection_reason,reviewed_by,reviewed_at', 'user_id')`. This is the
  first concrete reuse of `log_audit()` and validates the Phase 4 reusability
  invariant. Approve/reject through the
  `approve_account_approval_request` / `reject_account_approval_request` RPCs
  produces one `audit_logs` row with the admin as `actor_user_id` and the
  affected user's UUID as `target_id`.
- Phase 6: `user_roles` ✅ **Shipped** in `20260515120004_create_user_roles.sql` via **two separate triggers** — `log_audit()` takes the action string verbatim from `TG_ARGV[0]`, so one trigger per legal mutation event is required:
  - `trg_user_roles_audit_granted` — AFTER INSERT, action key `user_role.granted`, target column `user_id`.
  - `trg_user_roles_audit_revoked` — AFTER DELETE, action key `user_role.revoked`, target column `user_id`.
  - No UPDATE trigger in v1 — `user_roles` rows are immutable post-insert.
  - The Phase 6 backfill migration (`20260515120007`) emits many `user_role.granted` rows with `actor_user_id = NULL` (runs as `postgres`, no `auth.uid()`). Phase 7+ in-app grants will have `actor_user_id = <super_admin uuid>`.
- Phase 7: roles, role-permissions, and permissions ✅ **Shipped** in `20260516120001_create_phase7_audit_triggers.sql`:
  - `role.created` — `roles` AFTER INSERT.
  - `role.updated` — `roles` AFTER UPDATE.
  - `role.deleted` — `roles` AFTER DELETE.
  - `role_permission.granted` — `role_permissions` AFTER INSERT.
  - `role_permission.revoked` — `role_permissions` AFTER DELETE.
  - `permission.created` — `permissions` AFTER INSERT.
  - `permission.updated` — `permissions` AFTER UPDATE.
  - `permission.deleted` — `permissions` AFTER DELETE.
  - The `permissions` triggers are defensive coverage for future catalog maintenance; the Phase 7 app does not mutate permission rows.
- Phase 8: governorates, cities, and areas ✅ **Shipped** in migrations `20260517120001`/`20260517120002`/`20260517120003` (FR-007):
  - `governorate.created` — `governorates` AFTER INSERT.
  - `governorate.updated` — `governorates` AFTER UPDATE.
  - `governorate.deleted` — `governorates` AFTER DELETE.
  - `city.created` — `cities` AFTER INSERT.
  - `city.updated` — `cities` AFTER UPDATE.
  - `city.deleted` — `cities` AFTER DELETE.
  - `area.created` — `areas` AFTER INSERT.
  - `area.updated` — `areas` AFTER UPDATE.
  - `area.deleted` — `areas` AFTER DELETE.
  - All seed rows (14 governorates + 32 cities + 9 areas) produce `*.created` audit rows with `actor_user_id=NULL` (trigger attached BEFORE seed per R-08 / Clarifications Q5). This is the **fifth** reuse of `log_audit()` across Phases 4/5/6/7/8 (R-13 reusability invariant).
- Phase 9: currencies and exchange rates ✅ **Shipped** in migrations `20260518120001`/`20260518120002`/`20260518120003` (FR-007, FR-026):
  - `currency.created` — `currencies` AFTER INSERT.
  - `currency.updated` — `currencies` AFTER UPDATE.
  - `currency.deleted` — `currencies` AFTER DELETE.
  - `exchange_rate.updated` — `exchange_rates` AFTER INSERT.
  - Seed rows (SYP + USD currencies, plus the starter USD/SYP rate pair) produce audit rows with `actor_user_id=NULL` because triggers attach BEFORE seed per R-08.
  - The `update_exchange_rate` RPC produces TWO `exchange_rate.updated` audit rows per call: one for the admin-authored row and one for the auto-derived inverse row. The derived row's `after_state.source` starts with `auto-derived from ` followed by the admin row UUID.
- Phase 12: listings workflow
- Phase 18: reports/moderation
- Phase 19: agency flows
- Phase 21: ads

In Phase 4 trigger-context writes, `ip` and `user_agent` remain NULL. Later edge
function paths can populate those fields where request metadata is available.
