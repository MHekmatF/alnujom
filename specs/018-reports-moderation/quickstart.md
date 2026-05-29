# Quickstart — Reports & Moderation (manual verification recipe)

**Feature**: `specs/018-reports-moderation/` | Reference device: Infinix Note 8 (480 dp) + Pixel 8 Pro AVD (412 dp). Run with `--dart-define-from-file=.env.json` (memory `project_dart_defines.md`). No new automated tests (memory `feedback_no_new_tests.md`) — this recipe is the gate.

## 0. Apply backend (Supabase MCP `apply_migration`, in order)

1. `20260530120001_create_reports_table.sql`
2. `20260530120002_create_moderation_actions_table.sql`
3. `20260530120003_create_reports_policies.sql`
4. `20260530120004_create_v_reports_view.sql`
5. `20260530120005_create_reports_audit_trigger.sql`
6. `20260530120006_create_submit_report_rpc.sql`
7. `20260530120007_create_resolve_report_rpcs.sql`
8. `20260530120008_phase18_advisor_hardening.sql`

Then deploy the `resolve_report` Edge Function. Confirm `get_advisors` reports no new RLS/security-definer warnings. **Before writing the resolve RPC body**, verify the Phase 10 `listing_status_transition_trigger_fn` (`20260519120006`) permits `approved→{paused,rejected,deleted}` (R-124 integration check).

## 1. Fixtures

- user-A, user-B (approved accounts, no `reports.manage`).
- mod-M (holds `reports.manage` via the `moderator` role).
- ≥ 3 approved listings L1, L2, L3.

## 2. Submit (SC-001, SC-011)

1. Anonymous: open L1 details → Report CTA visible (not hidden). Tap → "Sign in to report" prompt + routes to `/login`. `SELECT count(*) FROM reports` unchanged. ✓ SC-011.
2. Sign in as user-A → L1 → Report → sheet shows 8 reasons + note. Pick `fake_listing`, add a note, submit → confirmation < 30 s. `SELECT * FROM reports WHERE listing_id=L1 AND reporter_user_id=A` → one row, `status='new'`. ✓ SC-001.

## 3. Open-report dedup (SC-002)

1. user-A taps Report on L1 again → "already reported"; no second row. ✓
2. (After §6 resolves it) user-A reports L1 again → a NEW row is created. ✓ SC-002.

## 4. Admin gating + queue (SC-003, SC-014)

1. Sign in as user-A → admin home shows NO Reports tile; navigate to `/admin/reports` → redirected. `select * from v_reports` from A → only A's own rows. ✓
2. Sign in as mod-M → admin home shows Reports tile → queue lists all reports newest-first with listing/reason/reporter/note. Status + reason filters narrow correctly. Inspect the query → `LIMIT`/cursor present (no full scan). ✓ SC-003, SC-014.

## 5. Start review soft lock (FR-036)

1. mod-M taps "Start review" on a `new` report → `reviewing`, `reviewing_by=M`. Resolve still available. A second admin (if seeded) sees "being reviewed by M" but can still resolve. ✓

## 6. Resolve — four actions (SC-004, SC-005, SC-006)

For each action, resolve a report and inspect:

| action | `reports.status` | `listings.status` | `moderation_actions` | `audit_logs` |
|--------|------------------|-------------------|----------------------|--------------|
| `dismiss` (L1) | `dismissed` | unchanged | 1 row `dismiss` | 1 `report.resolved` |
| `hide` (L2) | `resolved` | `paused` | 1 row `hide` | + listing `paused` audit |
| `mark_duplicate` (L2b) | `resolved` | `rejected` (reason duplicate in `listing_status_history`) | 1 row | + listing `rejected` audit |
| `delete` (L3) | `resolved` | `deleted` | 1 row | + listing `deleted` audit |

- After `hide`/`delete`: reload anonymous home feed / search / map → L2 / L3 absent within one refresh. ✓ SC-005.
- Inspect `resolve_report_internal` body → single transaction; SQL check: no resolved report lacks a `moderation_actions` row, no listing change lacks a report resolution. ✓ SC-006.

## 7. Sibling auto-resolve (FR-016)

1. Seed L2 with 2 more open reports (user-A, user-B). mod-M resolves one via `hide` → the other two move to `resolved`, each with its own `moderation_actions` row referencing the trigger. ✓
2. Repeat with `dismiss` on a fresh listing → siblings remain open. ✓

## 8. Concurrent / double resolve (SC-015)

1. Resolve a report, then resolve it again → second call returns `already_resolved`; still exactly one terminal state + one (triggering) `moderation_actions` row. ✓

## 9. Dual-layer authorization (SC-010)

1. As user-A, `POST /functions/v1/resolve_report` with a valid `report_id` → 403 `permission_denied` (Edge Fn gate).
2. As user-A, `supabase.rpc('resolve_report_internal', {...})` directly → permission denied (no client grant). `select count(*) from moderation_actions` unchanged. ✓ SC-010.

## 10. Read-matrix wire capture (SC-009)

Capture wire responses:
- user-A `select * from reports` → only A's rows. user-A with forged `where reporter_user_id='<B>'` → zero rows.
- anon `select * from reports` / `from moderation_actions` / `from v_reports` → zero / denied.
- user-A `select * from moderation_actions` → zero rows.
- mod-M `select * from reports` + `moderation_actions` → all rows. ✓ SC-009.

## 11. Reporter visibility (SC-007, SC-008)

1. user-A → Profile → "My Reports" → only A's reports newest-first with status + resolution. A fresh account → localized empty-state. ✓ SC-007.
2. user-A reopens a listing they reported → inline banner shows the current status. mod-M resolves it → user-A reloads → banner shows the terminal status. user-B (non-reporter) and anon → no banner. ✓ SC-008.

## 12. Theme × locale (SC-012)

Render the report sheet, admin queue + resolve dialog, My-Reports page, reporter banner, sign-in prompt, and empty-state in all 4 combinations (light/dark × ar-RTL/en-LTR) on 480 dp + 412 dp. All strings localized, directionally correct. ✓ SC-012.

## 13. Constitution grep gates (SC-013)

- `git diff --stat origin/main` → `pubspec.yaml` unchanged (zero new deps). ✓ FR-031.
- No hardcoded role branch (`if (role == ...)`) in `lib/features/reports/` or `lib/features/admin/reports/`; gating is `PermissionKeys.reportsManage` via `PermissionChecker`. ✓ FR-032.
- No `package:supabase_flutter` import under any `domain/` or `presentation/` of the two features. ✓ Principle IX.
- No inline `Text('...')` literal in the new feature code; all via `AppLocalizations`. ✓ Principle V.
- `lead_events.event_type` CHECK + `listings.status` CHECK unchanged. ✓ FR-034.
