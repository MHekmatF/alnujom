<!-- SPECKIT START -->
Active Spec Kit feature: `001-project-foundation` (Phase 1 — Project Foundation)

For technologies, project structure, and shell commands, read the plan:
[specs/001-project-foundation/plan.md](specs/001-project-foundation/plan.md)

Companion artifacts in the same folder:
- `spec.md` — user stories, FRs, success criteria, clarifications
- `research.md` — locked technical decisions and rationale
- `data-model.md` — User Preferences (local) entity; no DB tables in Phase 1
- `contracts/` — internal interface contracts (`SupabaseClientWrapper`, DI, router, `Result`/`Failure`, `AppLogger`, `PreferencesStore`)
- `quickstart.md` — end-to-end verification recipe

Cross-cutting: [docs/decisions/0001-secrets-and-pii-storage.md](docs/decisions/0001-secrets-and-pii-storage.md) — Supabase Vault is the canonical store for backend secrets and admin-only PII (lands Phase 4 onward; not a Phase 1 concern).
<!-- SPECKIT END -->
