# Phase 17 — Favorites — DEFERRED work

Status after the `/wave all --auto` build + the DB-apply/verification tail. Code is complete (analyze-clean, 225 tests green). **All 7 migrations are applied to Supabase** and the backend Success Criteria are verified at the data layer. The only remaining item is the on-device UI matrix.

## ✅ Done in the tail (orchestrator)

- Applied migrations `20260529120001`–`20260529120007` (table, policies, view, RPC, hardening, FK index, anon-revoke) via Supabase MCP. Repo ↔ DB in sync.
- Advisors run: the one Phase-17 performance finding (unindexed `favorites.listing_id` FK) fixed by `…120006`. The 3 `security_definer_view` security ERRORs are **pre-existing** (`v_listings_public`, `v_lead_events_publisher`, `v_lead_events_admin` from Phases 14/16) — **not** `v_favorites` (which is `security_invoker`); out of Phase 17 scope.
- Backend SCs verified via SQL role-simulation in `ROLLBACK` transactions (no test data persisted):
  - **SC-005 / SC-006** — cross-user read & delete isolation; anon read denied (`A_sees_B=0`, `A_deleted_B=0`, `anon_sees_any=0`, `B_row_persists=1`).
  - **SC-007** — `favorite_added` dedup once per `(user, listing)` (3 adds + un-favorite + re-add → exactly 1 event).
  - **SC-008** — favorite row + event co-commit atomically (1 favorite, 1 event).
  - **SC-011** — a favorite whose listing is no longer `approved` still appears in `v_favorites` with `is_available=false` (LEFT-JOIN review fix proven).
  - Rejections: draft listing → `23514 listing_not_approved`; anon `add_favorite` → `42501 permission denied` (after the FR-011 anon revoke); auth-required guard → `28000`.
- `tasks.md`: T008/T012/T013/T014/T017/T018/T019 closed `[X]` with evidence.

## §D-T046 — On-device UI Success-Criteria matrix (the only remaining gap)

**Status**: open — requires the app running on the reference Infinix Note 8 + Pixel 8 Pro AVD (cannot be exercised from SQL).
**Remaining criteria** (run `quickstart.md` §3–§11):
- **SC-001 / SC-002** — heart fills/empties ≤300 ms optimistic; row written/deleted ≤2 s.
- **SC-003** — a listing favorited on one surface shows favorited on every other surface in-session (home/search/map/details/FavoritesPage).
- **SC-004 / SC-012** — FavoritesPage lists saved listings newest-first; zero-favorites empty-state.
- **SC-009** — favorites persist across app restart, reinstall, and a second device.
- **SC-010** — anonymous heart is visible and tapping it routes to sign-in (no pre-auth save).
- **SC-013** — render matrix: light/dark × Arabic-RTL/English-LTR.

**Why this is the gate before merge**: per the project's strict-completion rule, these UI criteria must be ticked on a device before `017-favorites` squash-merges to `main`. The branch + PR #23 are ready; the merge waits on this manual pass.

## Merge-to-main tail (human-gated)

Squash-merge PR #23 once §D-T046 is green. Not done autonomously.
