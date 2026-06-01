# Quickstart: Admin Dashboard (Phase 20)

End-to-end manual verification recipe. No new automated tests (project MVP convention). Run on the Pixel 8 Pro AVD and/or the Infinix Note 8, plus wire-level SQL/RPC checks. Each step maps to Success Criteria.

## Prerequisites

- Apply the TWO Phase 20 migrations in order (via Supabase MCP `apply_migration`, per `project_supabase_apply_via_mcp`): `20260601120003_create_admin_dashboard_counts.sql` (counts fn) and `20260601120004_align_audit_logs_read_to_permission.sql` (swaps the existing `audit_logs_select_admin` read predicate from the role-based `current_user_is_admin()` to `current_user_has_permission('audit_logs.view')`).
- Run `dart run build_runner build --delete-conflicting-outputs` (regenerates `injection.config.dart` for the two new feature trees).
- Launch with `flutter run --dart-define-from-file=.env.json` (per `project_dart_defines`).
- Seed a fixture with known counts: ≥ N pending account-approval requests, ≥ M `pending_review` listings, ≥ K open reports (`new`/`reviewing`), ≥ J inquiries created within 24h, ≥ L `approved` in-window listings, and several `audit_logs` rows.
- Test accounts: a **super-admin**, a **moderator** (`listings.approve` + `reports.manage` + `users.view`, NO currencies/roles/settings/inquiries), and a **non-admin** user.

## Steps

1. **Migrations apply cleanly + audit policy aligned** — `select proname from pg_proc where proname='admin_dashboard_counts'` returns one row; the `audit_logs_select_admin` policy's `USING` clause now references `current_user_has_permission('audit_logs.view')` (not `current_user_is_admin()`) — confirm via `select pg_get_expr(polqual, polrelid) from pg_policy where polname='audit_logs_select_admin'`. *(setup)*

2. **Dashboard replaces the old admin home in place** — sign in as super-admin, open `/admin`; confirm the unified grid renders (not the old plain `ListView`) at the same route, with counters. *(FR-001)*

3. **Tiles match permissions — super-admin** — confirm all sections render: Users, Listings, Reports, Agencies, Inquiries, Locations, Currencies, Roles&Permissions, Audit logs, plus disabled coming-soon Ads + Settings. *(SC-001)*

4. **Tiles match permissions — moderator** — sign in as moderator; confirm ONLY Listings, Reports, Users tiles render; Currencies/Roles/Settings/Inquiries/Agencies/Locations/Audit-logs are ABSENT; Ads/Settings coming-soon are absent (no `ads.manage`/`settings.manage`). *(SC-001)*

   4b. **Permission grant reshapes dashboard** — grant `reports.manage` to a role the moderator lacks it on (or `audit_logs.view`), refresh the session (re-login or `PermissionChecker.refresh()`), reopen `/admin`; confirm the corresponding tile AND counter now appear with no code change. *(SC-011)*

5. **Counters match fixture (< 2 s)** — as super-admin, confirm each counter equals the seeded count: pending users = N, pending listings = M, open reports = K, new inquiries (24h) = J, active listings = L, within ~2 s of opening. *(SC-003)*

6. **Refresh model** — from a second session submit a new listing for review; back on the dashboard WITHOUT refreshing, confirm the counter is unchanged (no auto-update — Realtime deferred); pull-to-refresh (or leave + re-enter), confirm it increments. *(SC-005)*

   6b. **Usable when counts fail** — simulate a counts failure (e.g., temporarily revoke EXECUTE or kill connectivity); confirm tiles still render and navigate AND the counters show a localized error/retry state (no blank/crash). *(SC-010)*

7. **Quick-action deep links** — tap the pending-listings counter/tile → opens `/admin/listing-review/pending`; tap open-reports → `/admin/reports`; tap pending-users → `/admin/approvals`; tap new-inquiries → `/admin/inquiries`. *(SC-006)*

8. **Backend gate (checks at both ends)** — wire-level:
   - As `anon`, `rpc('admin_dashboard_counts')` is rejected (no grant). *(SC-002)*
   - As the moderator (no `inquiries.view_all`/`reports.manage`? — moderator HAS reports.manage; pick a missing key, e.g. `inquiries.view_all`), `select new_inquiries_24h from admin_dashboard_counts()` returns `NULL` while `pending_listings` is non-NULL. *(SC-004)*
   - As the non-admin, `/admin` route redirects away AND `rpc` returns all-NULL/denied. *(SC-002)*

9. **Four-combination render** — cycle (light, ar) / (dark, ar) / (light, en) / (dark, en) on the Infinix Note 8 (≈480 dp) and a 412 dp emulator; confirm the grid, counters, coming-soon tiles, and all states are localized, RTL/LTR-correct, and use Phase 2 tokens (no clipping, no inline hex). *(SC-007)*

10. **Constitution grep gates** — confirm: zero new pubspec packages (`git diff pubspec.yaml` empty for deps); zero new permission keys (`permission_keys.dart` + `20260515120002` unchanged); zero hardcoded role branches in `lib/features/admin/dashboard/` + `audit_logs/` (only `PermissionChecker`/`current_user_has_permission`); no Supabase `.channel(`/Realtime in the new code. *(SC-009)*

11. **Audit-log viewer (gated by the swapped `audit_logs.view` policy)** — as super-admin (holds `audit_logs.view`), open the Audit-logs tile → the viewer lists recent entries newest-first (actor, action, target, timestamp), paginates, and offers NO create/edit/delete. As the moderator (no `audit_logs.view`), confirm no Audit-logs tile AND a direct nav to `/admin/audit-logs` redirects to `/admin?denied=audit_logs` AND a wire-level `select … from audit_logs` returns zero rows. Bonus (validates the swap vs. the old role gate): grant a NON-admin custom role with ONLY `audit_logs.view` and confirm that user CAN read the log — proving the gate is now permission-based, not role-based. *(SC-012, FR-021)*

## Pass criteria

All 11 steps pass on the reference device; the wire-level checks (steps 8, 11) confirm permission enforcement at the data layer, not just the UI.
