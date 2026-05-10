<!-- SPECKIT START -->
Active Spec Kit feature: `005-auth-profile` (Phase 5 — Auth & Profile)

For technologies, project structure, and shell commands, read the plan:
[specs/005-auth-profile/plan.md](specs/005-auth-profile/plan.md)

Companion artifacts in the same folder:
- `spec.md` — user stories, FRs, success criteria, clarifications (Session 2026-05-10 closed five questions: Vault storage mechanism = `vault.secrets` per-user-per-field; `private_contact_methods` shape = JSON with allowlisted typed keys; password policy = 8 chars no-complexity; admin-queue scope = pending-only with approve/reject; locale source after first sign-in = server wins)
- `research.md` — 21 locked technical decisions (R-01 migration filenames + divergence from IMPLEMENTATION_PLAN.md naming, R-02 inherited apply mechanism, R-03 hand-rolled phone-number value object, R-04 account_approval_requests narrower lifecycle, R-05 `log_audit()` reuse, R-06 synthetic-email helper location, R-07/R-16 `request_password_reset` Edge Function justification, R-08 password-policy wiring, R-09 BLoC vs Cubit per feature, R-10 onboarding-seen flag, R-11 locale handoff at registration time, R-12 admin-predicate body swap, R-13 Vault PII helper signatures, R-14 atomic approve/reject RPCs, R-15 phone uniqueness via synthetic email, R-17 profile-edit validation, R-18 AuthBloc state machine, R-19 first-admin bootstrap, R-20 UUID PK for request rows, R-21 foreground-refresh suspension detection)
- `data-model.md` — `account_approval_requests` table + `account_approval_status` enum; `profiles.is_admin` column; the five Vault PII SECURITY DEFINER helpers; the `approve_account_approval_request` / `reject_account_approval_request` admin RPCs; the `current_user_is_admin()` body swap; the auto-population + audit triggers; the AuthBloc state machine; the secret naming convention `pii.<user_id>.<field_name>`
- `contracts/` — eight interface contracts: `account-approval-trigger`, `account-approval-audit-trigger`, `admin-predicate-v5` (the body-swap of the Phase 4 placeholder), `vault-pii-helpers`, `auth-repository`, `profile-repository`, `phone-number-value-object`, `request-password-reset-edge-fn` (Phase 5's only Edge Function — divergence from IMPLEMENTATION_PLAN.md justified by FR-017's account-enumeration resistance)
- `quickstart.md` — end-to-end manual verification recipe (20 steps via Supabase MCP `execute_sql` + `deploy_edge_function` against the remote project + Flutter UI walk on Infinix Note 8); no automated tests

Predecessors (still relevant — Phase 5 builds on top of them):
- [specs/004-supabase-foundation/plan.md](specs/004-supabase-foundation/plan.md) — Phase 4 source-controlled backend skeleton (`profiles`, `user_preferences`, `audit_logs`, the §6.3 enums, the auto-provision trigger, the reusable `log_audit()` function, the `current_user_is_admin()` placeholder Phase 5 swaps the body of, the Vault scaffolding Phase 5's PII helpers wrap). Phase 5 makes zero edits to Phase 4's policy files (R-05 invariant preserved).
- [specs/003-localization/plan.md](specs/003-localization/plan.md) — Phase 3 ARB-driven localization. Phase 5 closes the secure-storage → `user_preferences` locale handoff at registration time (R-11).
- [specs/002-design-system/plan.md](specs/002-design-system/plan.md) — design tokens + bilingual font stack consumed by Phase 5's auth/profile/onboarding/admin pages.

Cross-cutting: [docs/decisions/0001-secrets-and-pii-storage.md](docs/decisions/0001-secrets-and-pii-storage.md) — Supabase Vault for backend secrets and admin-only PII. Phase 5 stores the first real PII secrets (`legal_name`, `national_id`, `private_contact_methods` per user) via the Phase 4 scaffolding.
<!-- SPECKIT END -->
