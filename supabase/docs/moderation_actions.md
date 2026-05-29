# moderation_actions

## Purpose

`public.moderation_actions` is the Phase 18 append-only audit trail of admin
moderation decisions. One row is written per resolved report -- the triggering
report plus any auto-resolved siblings (FR-016). Rows are written ONLY by the
service-role `resolve_report_internal` RPC (Migration 7,
`20260530120007`) and are readable ONLY by holders of the `reports.manage`
permission.

Authoritative interface contract:
[`specs/018-reports-moderation/contracts/phase18-moderation-actions-table.md`](../../specs/018-reports-moderation/contracts/phase18-moderation-actions-table.md).

## Shape

Defined in `supabase/migrations/20260530120002_create_moderation_actions_table.sql`.

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | `uuid` | PK, DEFAULT `gen_random_uuid()` | Action identifier. |
| `target_type` | `text` | NOT NULL, DEFAULT `'listing'`, CHECK in {`listing`} | The moderated entity kind (only listings today). |
| `target_id` | `uuid` | NOT NULL | The reported listing. **Plain column, NO FK** (R-131) -- the audit log is decoupled from listing lifecycle and survives a target hard-delete. |
| `report_id` | `uuid` | NULL, FK -> `public.reports(id)` ON DELETE SET NULL | The resolved report; the log entry survives the report's deletion. |
| `action` | `text` | NOT NULL, CHECK in {`dismiss`,`hide`,`mark_duplicate`,`delete`} | The moderation decision taken. |
| `performed_by` | `uuid` | NULL, FK -> `auth.users(id)` ON DELETE SET NULL | The moderator; the log survives the moderator's account deletion. |
| `performed_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | When the action was recorded. |
| `reason` | `text` | NULL | Moderator note / auto-resolve provenance. |
| `before_state` | `jsonb` | NULL | Listing `(status,title)` before the action. |
| `after_state` | `jsonb` | NULL | Listing `(status,title)` after the action. |

## Index

`idx_moderation_actions_target (target_type, target_id, performed_at DESC)` --
the per-listing moderation history, newest-first.

## FK delete behaviors (R-131)

| FK column | References | ON DELETE behavior | Rationale |
|-----------|-----------|-------------------|-----------|
| `target_id` | (none -- plain uuid) | n/a | Deliberately NO FK so the moderation trail outlives the target listing's lifecycle (audit decoupling). |
| `report_id` | `public.reports(id)` | **SET NULL** | The log entry survives report deletion (e.g. reporter-account cascade); attribution to the report goes null, row stays. |
| `performed_by` | `auth.users(id)` | **SET NULL** | The log entry survives the moderator's account deletion. |

## Invariants

- **Append-only**: never UPDATE-d or DELETE-d by application code.
- Every resolved report (the triggering report plus each auto-resolved sibling)
  produces exactly one row (SC-004, SC-006).
- No client write path -- Migration 3 REVOKEs INSERT/UPDATE/DELETE; the only
  writer is the service-role `resolve_report_internal` RPC.

## RLS posture (forward-stated)

- **Migration 2 (this file)**: `ALTER TABLE public.moderation_actions ENABLE ROW
  LEVEL SECURITY` is set. NO policies are attached -- default-deny until
  Migration 3 attaches the admin reader policy.
- **Migration 3 (`20260530120003_create_reports_policies.sql`)** will add:
  - `moderation_actions_select_admin` -- SELECT for `authenticated` where
    `public.current_user_has_permission('reports.manage')`. Admin-only read; no
    reporter, publisher, or anonymous reader path.
  - `REVOKE INSERT, UPDATE, DELETE ON public.moderation_actions FROM
    authenticated, anon` -- no client write path of any kind.

The full live reader/writer matrix lands in Migration 3 (data-model section 1.9)
and is appended to this doc in Sub-Phase C (T016).

## RLS reader/writer matrix (live — Migration 3, data-model §1.9)

Attached by `supabase/migrations/20260530120003_create_reports_policies.sql`.
This matrix is load-bearing (Principle III) and is the SC-009 test surface.

| Actor | `reports` SELECT | `reports` INSERT | `reports` UPDATE/DELETE | `moderation_actions` SELECT | `moderation_actions` write |
|-------|------------------|------------------|--------------------------|------------------------------|----------------------------|
| Anonymous | ❌ (no anon policy) | ❌ | ❌ | ❌ | ❌ |
| Authenticated reporter | ✅ own rows only | ❌ (RPC only) | ❌ | ❌ | ❌ |
| Authenticated non-reporter (no perm) | ✅ own rows only | ❌ | ❌ | ❌ | ❌ |
| `reports.manage` holder | ✅ ALL rows | ❌ (RPC only) | ❌ (Edge Fn → service-role RPC only) | ✅ ALL rows | ❌ (resolve RPC only) |
| `service_role` (Edge Fn) | n/a (bypasses RLS) | via RPC | via `resolve_report_internal` | n/a | via `resolve_report_internal` |

For `public.moderation_actions` specifically:

- `moderation_actions_select_admin` (TO `authenticated`):
  `USING (public.current_user_has_permission('reports.manage'))` — admin-only
  read; no reporter, publisher, or anonymous reader path (FR-026, FR-028).
- `REVOKE INSERT, UPDATE, DELETE ON public.moderation_actions FROM authenticated,
  anon` — append-only, written ONLY by the service-role
  `resolve_report_internal` RPC (Migration 7).
- No `anon` SELECT policy ⇒ anonymous sessions are denied entirely (FR-027).

## `v_reports` scoping note (Migration 4)

`moderation_actions` rows are NOT projected through `v_reports`; that SECURITY
INVOKER view serves the report queue / My-Reports surfaces only. The admin
moderation-history surface reads `public.moderation_actions` directly under
`moderation_actions_select_admin`.

## Audit relationship (Migration 5)

A `moderation_actions` row and an `audit_logs` row are written for the same
resolve event from different mechanisms: `resolve_report_internal` (Migration 7)
INSERTs the `moderation_actions` row explicitly, while the
`trg_reports_audit_resolution` trigger (Migration 5, reusing Phase 4
`log_audit()`) writes the `audit_logs` row on the report's terminal status
transition. Both co-commit in the single resolve transaction (FR-013, FR-035).
