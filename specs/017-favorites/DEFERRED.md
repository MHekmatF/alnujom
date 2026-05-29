# Phase 17 — Favorites — DEFERRED work

**Status: NONE OPEN.** All deferrals have been closed. Phase 17 is fully implemented, all 7 migrations are applied to Supabase, and every Success Criterion (SC-001..SC-015) is verified. All 48 tasks in `tasks.md` are `[X]`.

## §D-T046 — On-device UI Success-Criteria matrix — ✅ RESOLVED

Verified on the reference **Infinix Note 8** (user QA): SC-001/SC-002 (toggle speed + persist), SC-003 (cross-surface heart consistency), SC-004/SC-012 (FavoritesPage list + empty-state), SC-009 (persistence across app restart), SC-010 (anonymous heart → sign-in prompt), SC-013 (light/dark × Arabic/English). Backend SCs (SC-005/006/007/008/011) were verified earlier via SQL role-simulation against the live database.

## Record of the DB-apply tail (completed)

All 7 migrations applied via Supabase MCP (repo ↔ DB in sync): `20260529120001`–`20260529120007` (table, policies, `v_favorites` view, `add_favorite` RPC, hardening, `listing_id` FK index, anon EXECUTE revoke). Advisors: zero new Phase-17 findings (the 3 `security_definer_view` ERRORs are pre-existing Phase 14/16 views, not `v_favorites`).
