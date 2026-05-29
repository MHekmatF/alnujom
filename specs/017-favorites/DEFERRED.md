# Phase 17 — Favorites — DEFERRED work

Intentional gaps left at the end of the `/wave all --auto` autonomous build. Each item is blocked on a human/device step the orchestrator does not perform autonomously (live Supabase DB changes; on-device QA; merge to `main`). Nothing here is a code defect — the implementation is complete, analyze-clean, and tests-green on the branch.

## §D-T046 — Manual Success-Criteria matrix (SC-001..SC-013) on devices

**Status**: deferred (blocked on the DB-apply tail + physical/emulator devices).
**Task**: `tasks.md` T046.
**Why deferred**: the autonomous waves built and verified all code (`flutter analyze --fatal-infos` clean, 225 existing tests pass, all 5 grep gates pass), but the runtime SC matrix requires (a) the 5 Phase-17 migrations applied to the live Supabase project and (b) the app running on the reference Infinix Note 8 + Pixel 8 Pro AVD — neither of which the orchestrator does under `--auto` (live-DB + device QA are human-gated).
**To close**: after the migrations are applied (see the DB-apply tail below), run `quickstart.md` §3–§11 and tick SC-001..SC-013. Record any per-criterion partial here.

## DB-apply tail (human/orchestrator-gated — NOT done autonomously)

The 5 migrations exist as committed files but were **never applied** to Supabase during the autonomous build (live schema changes are outside `--auto`'s grant). Apply in filename order via Supabase MCP `apply_migration` (per `quickstart.md` §1), then verify:

1. `20260529120001_create_favorites_table.sql`
2. `20260529120002_create_favorites_policies.sql`
3. `20260529120003_create_v_favorites_view.sql`
4. `20260529120004_create_add_favorite_rpc.sql`
5. `20260529120005_phase17_advisor_hardening.sql`

Then run `get_advisors` (security + performance) and confirm zero new warnings. These correspond to the deferred `tasks.md` items T008, T012, T013, T014 (smoke), T017, T018, T019.

## Merge-to-main tail (human-gated)

The single end-of-spec PR squash-merge to `main` is **not** performed autonomously (destructive/outward). The `017-favorites` branch is pushed and PR-ready.
