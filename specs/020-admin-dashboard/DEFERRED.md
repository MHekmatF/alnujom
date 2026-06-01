# Deferred work — Phase 20 (Admin Dashboard)

Intentional gaps left at the end of the `/wave all --auto` run on **2026-06-01**. All
*code* tasks (T001–T024) are complete, merged, applied to the live project, and
verified to the extent possible without an interactive device/AVD session
(`flutter analyze --fatal-infos` clean, 225 tests pass, Opus review pass applied,
wire-level RPC/RLS gate proofs via Supabase MCP). The items below all require an
on-device / AVD walk or a non-existent seed-data permission combination, which the
autonomous orchestrator could not perform. They are **verification-completeness**
items, not missing functionality.

Per memory `feedback_avd_acceptable_qa`, a Pixel 8 Pro AVD walk is acceptable
primary QA for this MVP (the Infinix Note 8 is not gating here — the dashboard is
not performance-sensitive).

---

## D-1 — Data-driven reshape: live UI walk (T018, SC-011)

**Status**: PARTIAL — data layer proven, UI walk deferred.

- **Done (autonomous)**: the FR-015 grep gate passed (zero hardcoded role branches),
  and the data-driven reshape is proven at the data layer — the same
  `admin_dashboard_counts()` RPC returns different counters purely as a function of
  the caller's permission set, with zero code change (T017 wire proofs).
- **Deferred**: grant a permission (e.g. `reports.manage` or `audit_logs.view`) to a
  test user's role → re-login (refreshes `PermissionChecker`) → reopen `/admin` →
  confirm the corresponding tile + counter now appear with no code change.
- **Why deferred**: requires a real auth session + re-login on a device/AVD.

## D-2 — Mixed partial-admin wire row (T017, SC-004)

**Status**: structurally entailed, not exercised live.

- **Done**: anon `EXECUTE` denied; no-roles session → all five counters NULL;
  `super_admin` → all five non-NULL; per-counter `CASE` isolation confirmed in SQL.
- **Deferred / N/A**: the exact mixed row — a session holding listings perms but **not**
  `reports.manage` returning `open_reports = NULL` while `pending_listings` is
  non-NULL — was not exercised because **no seeded user holds a partial admin set**
  (all admins are full `admin`/`super_admin`). It is entailed by the per-counter
  independence + the two endpoint proofs. To exercise live, seed a custom role with a
  subset of section permissions and impersonate it.

## D-3 — Four-combination render walk (T025, SC-007, FR-017)

**Status**: PARTIAL — static layer verified, visual walk deferred.

- **Done (autonomous)**: `flutter analyze --fatal-infos` clean; the Opus UI review
  confirmed Phase 2 tokens (no inline hex; one minor `size: 32` / badge-padding nit
  logged to `docs/ui_completion_backlog.md`, not a gate violation); existing
  `ThemeGallery` widget tests render light/dark × ar/en.
- **Deferred**: the on-device/AVD visual pass — (light/dark) × (ar-RTL/en-LTR) across
  the new dashboard grid, the five counters (incl. the secondary active-listings
  caption), coming-soon tiles, loading/empty-zero/error states, and the audit viewer;
  confirm direction-correctness and no overflow at ≈480 dp and 412 dp.

## D-4 — Full quickstart device steps (T027)

**Status**: PARTIAL — wire/static steps done, device steps deferred.

- **Done (autonomous)**: quickstart step 1 (both migrations applied + advisors, T006),
  step 8 (wire-level gate, T017), the FR-015 grep + constitution gates (T026),
  build/analyze/test green.
- **Deferred (device/AVD walk)**: tile-set-differs-by-role (moderator vs super-admin);
  counter equals seeded fixture within ~2 s; quick-action deep links land on the
  correct filtered queues; submit-from-another-session → counter unchanged until
  pull-to-refresh; audit viewer lists newest-first + paginates + no write affordance;
  non-holder sees no Audit tile and `/admin/audit-logs` redirects; the four-combo
  render (D-3).

---

## UI backlog (cosmetic — not gating)

Logged for a future polish pass (not blockers):

- `dashboard_tile.dart` / `coming_soon_tile.dart`: icon `size: 32` → `AppSpacing.xxl`
  and the badge `vertical: 2` padding → an `AppSpacing` token, for consistency with the
  Phase 18/19 admin tiles. (Review rated low-risk; much of the older codebase uses
  raw `size: N`.)
