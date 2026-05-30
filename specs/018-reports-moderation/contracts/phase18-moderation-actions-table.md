# Contract — `public.moderation_actions` table

**Migration**: `supabase/migrations/20260530120002_create_moderation_actions_table.sql` (Sub-Phase B)

Append-only record of an admin moderation action. One row per resolved report (the triggering report plus any auto-resolved siblings, FR-016). Written ONLY by `resolve_report_internal`; readable ONLY by `reports.manage` holders.

## Columns

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK, `DEFAULT gen_random_uuid()` |
| `target_type` | TEXT | NOT NULL, DEFAULT `'listing'`, CHECK ∈ {`listing`} |
| `target_id` | UUID | NOT NULL — the reported listing; **plain column, NO FK** (audit decoupled from listing lifecycle, R-131) |
| `report_id` | UUID | NULL, FK → `public.reports(id)` `ON DELETE SET NULL` (log survives report deletion) |
| `action` | TEXT | NOT NULL, CHECK ∈ {`dismiss`,`hide`,`mark_duplicate`,`delete`} |
| `performed_by` | UUID | NULL, FK → `auth.users(id)` `ON DELETE SET NULL` (log survives admin deletion) |
| `performed_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `now()` |
| `reason` | TEXT | NULL — moderator note / auto-resolve provenance |
| `before_state` | JSONB | NULL — listing `(status,title)` before |
| `after_state` | JSONB | NULL — listing `(status,title)` after |

## Index

- `idx_moderation_actions_target (target_type, target_id, performed_at DESC)`.

## Invariants

- No client write path (REVOKE INSERT/UPDATE/DELETE). RLS enabled; SELECT only for `reports.manage` (`20260530120003`).
- Append-only: never UPDATE-d or DELETE-d by application code.
- Every resolved report (triggering + sibling) produces exactly one row (SC-004, SC-006).

## Smoke tests

1. Resolve a report with `hide` → exactly one row (`action='hide'`, `before_state.status='approved'`, `after_state.status='paused'`).
2. Resolve a report on a listing with 2 other open reports via `delete` → 3 rows (1 triggering + 2 sibling), each `action='delete'` (FR-016).
3. Non-`reports.manage` SELECT → zero rows (RLS).
