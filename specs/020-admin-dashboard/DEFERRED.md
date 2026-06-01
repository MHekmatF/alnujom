# Deferred work — Phase 20 (Admin Dashboard)

Originally captured at the end of the `/wave all --auto` run (2026-06-01): the items
below were the device/AVD-dependent verification gaps the autonomous run could not
perform. **They were subsequently walked on-device on 2026-06-01** (Infinix Note 8,
X692, Android 10, 720×1640 ≈ 360 dp, live Phase-20 build, driven via adb + screenshots).
**D-1, D-2, D-3, D-4 are now RESOLVED.** A small low-value residual remains (see bottom).

QA method: real signup flow for the test accounts (no raw `auth.users` inserts);
approval + role assignment via Supabase MCP; navigation + capture via adb; GoRouter
logs + screenshots as the oracle. Two test accounts + one custom role were created on
the live project at the user's direction and **retained** (user chose "keep everything"):
- Moderator `+963991000001` (roles: user, moderator, qa_audit_only)
- Non-admin `+963991000002` (role: user)
- Custom role `qa_audit_only` (holds only `audit_logs.view`)

---

## D-1 — Data-driven reshape (T018, SC-011) — ✅ RESOLVED

As the moderator (no `audit_logs.view`), `/admin` showed **no Audit-logs tile**. Granted
`audit_logs.view` via the custom `qa_audit_only` role → **re-logged in** → the
**Audit-logs tile appeared** with zero code change, and the moderator could **read** the
audit log (the entries shown were the very grants just made). Proves the gate is
permission-based, not role-based (SC-011, SC-012, FR-021). FR-015 grep gate also passed.

## D-2 — Mixed partial-admin gating (T017, SC-004) — ✅ RESOLVED

The moderator IS a real partial-admin: `/admin` rendered only its 3 permitted tiles
(Listings/Approvals/Reports) and only its permitted counters (pending_users,
pending_listings + active_listings, open_reports) — **no `new_inquiries` counter**
(lacks `inquiries.view_all`). The same RPC/dashboard reshaped purely by permission set,
on-device, confirming the per-counter `CASE` gating for a mixed-permission session.

## D-3 — Four-combination render (T025, SC-007, FR-017) — ✅ RESOLVED

Dashboard **grid captured in all 4 combos** (en/light, ar/light, ar/dark, en/dark) +
audit viewer in en/light, en/dark, ar/dark. All strings localized (incl. the
"13 active listings / 13 إعلان نشط" caption), RTL mirrored correctly, dark
surfaces/icons/text correct, coming-soon (Ads/Settings) greyed + non-navigating, loading
states shown, **no overflow at ~360 dp**.

## D-4 — Full role/redirect walk (T027) — ✅ RESOLVED

Super-admin: all 11 sections + counters = live fixture (0/18/0/0 + "13 active") +
quick-action deep-links (Pending→pending queue, Reports→reports queue) + audit viewer
(newest-first, paginates, read-only) + pull-to-refresh + coming-soon non-navigating.
Moderator: 3-tile gated subset. Non-admin: **no admin entry point** (home app bar shows
only profile + globe; no admin shield).

---

## Residual (low value — not gating)

- **Dedicated 412 dp emulator pass**: not run separately. The device reports ~360 dp
  (narrower than the spec's ≈480 dp estimate, i.e. a *tighter* layout test), and the
  light/dark × ar/en `ThemeGallery` goldens pass — together these cover the width range.
- **Counts-failure error/retry state**: not exercised live (would require breaking the
  backend mid-session). The error/retry path is code-verified (FR-012) and the localized
  loading state was captured on-device.
- **OS dark-mode toggle on XOS**: the Infinix XOS build ignores the adb night-mode
  command; dark mode was toggled manually by the user for the dark combos.

## UI backlog (cosmetic — not gating)

- `dashboard_tile.dart` / `coming_soon_tile.dart`: icon `size: 32` → `AppSpacing.xxl`
  and the badge `vertical: 2` padding → an `AppSpacing` token, for consistency with the
  Phase 18/19 admin tiles. (Review rated low-risk.)
