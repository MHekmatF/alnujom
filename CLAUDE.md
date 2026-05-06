<!-- SPECKIT START -->
Active Spec Kit feature: `004-supabase-foundation` (Phase 4 — Supabase base schema + RLS scaffolding)

For technologies, project structure, and shell commands, read the plan:
[specs/004-supabase-foundation/plan.md](specs/004-supabase-foundation/plan.md)

Companion artifacts in the same folder:
- `spec.md` — user stories, FRs, success criteria, clarifications (Session 2026-05-06 closed five questions: preferences auto-provisioning, profiles-vs-user_preferences locus, full §6.3 enum scope, NULL+UNIQUE semantics, remote-only deployment via Supabase MCP)
- `research.md` — 11 locked technical decisions (R-01 migration application via Supabase MCP, R-02 migration filenames + policy bundling, R-03 native enums, R-04 `log_audit()` signature, R-05 `current_user_is_admin()` placeholder helper, R-06 `app_vault_secret()`, R-07 atomic auto-provision trigger, R-08 pgsodium baseline, R-09 real `authStateChanges()` wiring, R-10 Freezed entity shape, R-11 audit_logs UUID PK)
- `data-model.md` — `profiles`, `user_preferences`, `audit_logs` tables; 9 §6.3 enums; 5 functions (`handle_new_auth_user`, `log_audit`, `current_user_is_admin`, `app_vault_secret`, `set_updated_at`); 4 triggers; Flutter domain entities `Profile` and `UserPreferences` (plain Dart classes extending `Equatable` — no Freezed)
- `contracts/` — six interface contracts: `auto-provision-trigger`, `log-audit-trigger-fn` (the v1-stable reusable audit emitter), `admin-predicate` (Phase 5/6 swap target), `vault-helper`, `profile-entity`, `user-preferences-entity`
- `quickstart.md` — end-to-end manual verification recipe (20 steps via Supabase MCP `execute_sql` against the remote project + Flutter launch on Infinix Note 8); no automated tests

Predecessors (still relevant — Phase 4 builds on top of them):
- [specs/003-localization/plan.md](specs/003-localization/plan.md) — Phase 3 ARB-driven localization (Arabic-first, RTL/LTR, secure-storage locale persistence, lint guards). Phase 4 mirrors Phase 3's `'ar'` locale default into `user_preferences.locale = 'ar'` (FR-019); the Phase-3-to-Phase-5 locale-storage handoff (secure storage → `user_preferences` row) is Phase 5's concern.
- [specs/002-design-system/plan.md](specs/002-design-system/plan.md) — design tokens, bilingual font stack (Cairo / IBM Plex Sans Arabic / Inter), Theme Gallery. Phase 4 mirrors Phase 2's `ThemeMode` into `user_preferences.theme_mode = 'system'` (FR-019).

Cross-cutting: [docs/decisions/0001-secrets-and-pii-storage.md](docs/decisions/0001-secrets-and-pii-storage.md) — Supabase Vault for backend secrets and admin-only PII. Phase 4 ships the **scaffolding only** (`pgsodium` enable, `app_vault_secret(name)` helper, no secrets stored yet). Phases 5/16/19/21/22 store the first real secrets on top.
<!-- SPECKIT END -->
