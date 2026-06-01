# Data Model: Admin Dashboard (Phase 20)

Phase 1 output. Phase 20 introduces **no new tables, no new enum, no schema change to any table**. It adds two read-only backend migrations over existing tables: (1) one aggregate function for the counters, and (2) a one-statement predicate swap on the existing `audit_logs` read policy. Below: the two SQL migration bodies, the Dart domain entities, and a per-FR / per-SC verification map.

## 1. Backend artifacts

### 1.1 Migration `20260601120003_create_admin_dashboard_counts.sql` (P1)

A single `SECURITY DEFINER`, `STABLE` function returning one row with five nullable counts. Each counter is `NULL` when the caller lacks the section permission, so the client renders only permitted counters (FR-007/FR-013). `REVOKE` from `anon`; `GRANT` to `authenticated`.

```sql
-- Phase 20: admin dashboard operational counters (single bounded aggregate).
-- File: supabase/migrations/20260601120003_create_admin_dashboard_counts.sql
-- Spec: specs/020-admin-dashboard/spec.md (FR-006, FR-007, FR-008, FR-013, FR-014)
-- Contract: contracts/phase20-admin-dashboard-counts-rpc.md
-- SECURITY DEFINER so it can read the admin-only source tables; each counter is
-- re-gated on current_user_has_permission() so a caller sees only permitted counts
-- (Principle III "checks at both ends"; mirrors resolve_report_internal posture).

CREATE OR REPLACE FUNCTION public.admin_dashboard_counts()
RETURNS TABLE (
  pending_users     BIGINT,
  pending_listings  BIGINT,
  open_reports      BIGINT,
  new_inquiries_24h BIGINT,
  active_listings   BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- pending users — gate users.view / users.approve
    CASE WHEN current_user_has_permission('users.view')
           OR current_user_has_permission('users.approve')
         THEN (SELECT count(*) FROM public.account_approval_requests
                WHERE status = 'pending')
         ELSE NULL END,
    -- pending listings — gate listings.view_all / listings.approve
    CASE WHEN current_user_has_permission('listings.view_all')
           OR current_user_has_permission('listings.approve')
         THEN (SELECT count(*) FROM public.listings
                WHERE status = 'pending_review')
         ELSE NULL END,
    -- open reports — gate reports.manage
    CASE WHEN current_user_has_permission('reports.manage')
         THEN (SELECT count(*) FROM public.reports
                WHERE status IN ('new','reviewing'))
         ELSE NULL END,
    -- new inquiries last 24h — gate inquiries.view_all
    CASE WHEN current_user_has_permission('inquiries.view_all')
         THEN (SELECT count(*) FROM public.inquiries
                WHERE created_at >= now() - interval '24 hours')
         ELSE NULL END,
    -- active listings — gate listings.view_all / listings.approve
    CASE WHEN current_user_has_permission('listings.view_all')
           OR current_user_has_permission('listings.approve')
         THEN (SELECT count(*) FROM public.listings
                WHERE status = 'approved'
                  AND (expires_at IS NULL OR expires_at > now()))
         ELSE NULL END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_dashboard_counts() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_dashboard_counts() TO authenticated;
```

> Plan-time notes for `/speckit-tasks`: the exact `active_listings` window predicate MUST match whatever the Phase 13/14 public-read uses (`v_listings_public` / the listings public RLS) — re-base on the live predicate at implement time rather than assuming `expires_at`. **The pending-users count keys on `account_approval_requests.status = 'pending'`** — the column is `status` (an `account_approval_status` enum, per `20260510120001_create_account_approval_requests.sql:22`), NOT `decision` (the IMPLEMENTATION_PLAN §6.2 wrote `decision`, but the shipped migration uses `status`). The `reports.status` values (`'new'`,`'reviewing'`) and `listings.status` (`'pending_review'`/`'approved'`) are confirmed against Phases 18/10.

### 1.2 Migration `20260601120004_align_audit_logs_read_to_permission.sql` (P2)

The `audit_logs_select_admin` policy already exists (Phase 4, `20260506120005_enable_rls_default.sql`) but its `USING` clause is the **role-based** `current_user_is_admin()` — which Phase 6 (`20260515120006_swap_admin_predicate_to_role_check.sql`) redefined to "holds a role with key in `('admin','super_admin')`". The spec gates the Audit-logs surface on the data-driven `audit_logs.view` (FR-003/FR-021), and Principle VII forbids role-based gates. Phase 20 swaps the predicate so backend RLS and the frontend tile use the same gate. Net access is unchanged today (only admin/super_admin hold `audit_logs.view`); it diverges only for future custom roles — the intended data-driven behavior.

```sql
-- Phase 20: align the audit_logs read gate with the data-driven audit_logs.view permission.
-- File: supabase/migrations/20260601120004_align_audit_logs_read_to_permission.sql
-- Spec: specs/020-admin-dashboard/spec.md (FR-021, FR-003); Principle VII (no role-based gates).
-- Was: USING (current_user_is_admin())  [role-based, Phase 4 + Phase 6 swap]
-- Now: USING (current_user_has_permission('audit_logs.view'))  [data-driven]
-- Read-only: NO insert/update/delete policy — log_audit() (SECURITY DEFINER) remains the only writer.

DROP POLICY IF EXISTS audit_logs_select_admin ON public.audit_logs;
CREATE POLICY audit_logs_select_admin
  ON public.audit_logs
  FOR SELECT
  TO authenticated
  USING (current_user_has_permission('audit_logs.view'));

-- Reuses existing idx_audit_logs_created_at (created_at DESC) for newest-first pagination.
```

> The viewer reads via the existing `idx_audit_logs_created_at`. The table stays append-only — `log_audit()` (SECURITY DEFINER, Phase 4) remains the only writer; Phase 20 adds no INSERT/UPDATE/DELETE path.

---

## 2. Dart domain entities

Pure Dart (no `supabase_flutter` import) under `domain/entities/`. DTOs in `data/models/` map Supabase rows → these.

### 2.1 `DashboardCounts` (feature `dashboard`)

```dart
class DashboardCounts {
  final int? pendingUsers;       // null = caller not permitted to see this counter
  final int? pendingListings;
  final int? openReports;
  final int? newInquiries24h;
  final int? activeListings;
  const DashboardCounts({
    this.pendingUsers, this.pendingListings, this.openReports,
    this.newInquiries24h, this.activeListings,
  });
}
```
`null` is the "not permitted" signal (counter omitted); `0` is a real "nothing waiting" value (rendered — FR-010). The two are distinct.

### 2.2 `DashboardSection` (feature `dashboard`)

A value object describing one tile: localized-label key, icon, the gating permission key(s) (any-of), and either a destination route OR a `comingSoon` flag.

```dart
enum DashboardSectionState { enabled, comingSoon }

class DashboardSection {
  final String labelKey;              // resolved via AppLocalizations at render
  final List<String> permissionKeys;  // any-of gate (PermissionKeys.*)
  final String? route;                // AppRoutes.* when enabled
  final DashboardSectionState state;  // comingSoon → disabled, non-navigating
  // optional counter selector → which DashboardCounts field this tile shows
}
```

### 2.3 `AuditLogEntry` (feature `audit_logs`)

```dart
class AuditLogEntry {
  final String id;              // UUID (audit_logs.id is uuid)
  final String? actorUserId;    // nullable (ON DELETE SET NULL)
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, dynamic>? beforeState;
  final Map<String, dynamic>? afterState;
  final DateTime createdAt;
  const AuditLogEntry({ required this.id, this.actorUserId, required this.action,
    required this.targetType, this.targetId, this.beforeState, this.afterState,
    required this.createdAt });
}
```
> Note: `audit_logs.id` is `UUID` (Phase 4 `20260506120004`: `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`), not an int — the entity uses `String`.

---

## 3. Per-FR verification map

> Phase labels: **P1** = counts migration; **P2** = audit-policy swap + audit-log viewer (Flutter, owns the new route); **P3** = dashboard grid + counters (rewrites `admin_home_page.dart`).

| FR | Verified by |
|----|-------------|
| FR-001 upgrade `/admin` in place, reuse guard | `admin_home_page.dart` rewritten; `/admin` GoRoute + `authRedirect` unchanged (P3) |
| FR-002 tiles render only with permission | `PermissionChecker.has/any` wraps each tile (P3) |
| FR-003 canonical section set + keys | `DashboardSection` list incl. Inquiries + combined Roles/Permissions (P3) |
| FR-004 coming-soon Ads/Settings | disabled `ComingSoonTile`, gated, non-navigating (P3) |
| FR-005 hub not duplicate | each enabled tile `context.push` to existing route (P3) |
| FR-006 five counters | `admin_dashboard_counts()` returns 5 fields (P1) |
| FR-007 counter gated to section | per-counter `current_user_has_permission` CASE → NULL (P1) |
| FR-008 single bounded aggregate | one function, one round-trip, no client row-count (P1) |
| FR-009 quick-action deep links | counter/tile `onTap` → filtered queue route (P3) |
| FR-010 zero vs absent distinct | `0` rendered, `null` omitted (P3 + entity) |
| FR-011 on-entry + pull-to-refresh, no timer | `DashboardCubit.load()/refresh()`, no `Timer` (P3) |
| FR-012 loading/error states, tiles navigable | cubit states; tiles independent of counts (P3) |
| FR-013 server-side gate | SECURITY DEFINER + per-counter permission (P1) |
| FR-014 only permitted counts, no rows | function returns aggregates only, NULL when ungated (P1) |
| FR-015 data-driven, no role branch | only `PermissionChecker`/`current_user_has_permission`; audit-policy swap removes the role-based gate (P1+P2+P3) |
| FR-016 localized strings | ~25 keys in both ARBs (P2+P3) |
| FR-017 four-combination themed | Phase 2 tokens, logical insets (P2+P3) |
| FR-018 zero new deps | no pubspec change |
| FR-019 no new key/table | two functions/policies over existing tables; no schema change (P1+P2) |
| FR-020 no Realtime | no subscription; refresh manual (P3) |
| FR-021 read-only audit viewer | audit-policy swap to `audit_logs.view` (P2) + `AuditLogsViewerPage` (P2) |

## 4. Per-SC verification map

| SC | Verified by |
|----|-------------|
| SC-001 tiles match permissions (2 profiles) | quickstart steps 3–4 |
| SC-002 non-admin blocked (route + data) | quickstart step 8 (wire-level) |
| SC-003 counters match fixture < 2 s | quickstart step 5 |
| SC-004 ungated counter not retrievable | quickstart step 8 (`rpc` from non-permitted session) |
| SC-005 refresh updates; no auto-update | quickstart step 6 |
| SC-006 quick-action opens filtered queue | quickstart step 7 |
| SC-007 four-combo render | quickstart step 9 |
| SC-008 single bounded call | inspect `admin_dashboard_counts` body (P1) |
| SC-009 zero new deps/keys/branches/Realtime | quickstart step 10 |
| SC-010 usable when counts fail | quickstart step 6b |
| SC-011 grant permission → tile+counter appear | quickstart step 4b |
| SC-012 audit viewer read-only + gated | quickstart step 11 |
