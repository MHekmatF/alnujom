<!-- SPECKIT START -->
Active Spec Kit feature: `003-localization` (Phase 3 — Localization)

For technologies, project structure, and shell commands, read the plan:
[specs/003-localization/plan.md](specs/003-localization/plan.md)

Companion artifacts in the same folder:
- `spec.md` — user stories, FRs, success criteria, clarifications (lint scope = all of `lib/` minus exemption list; 7 seeded Syrian-Arabic terms; Theme Gallery chrome only; manual-verification posture, no new tests)
- `research.md` — locked technical decisions (gen-l10n config, secure-storage persistence, FR-008 missing-key wrapper strategy, literal/parity lint scripts, exemption-list shape, ARB corpus floor, CI integration)
- `data-model.md` — `Locale Preference`, `Translation File`, `Translation Key`, `Lint Exemption List`, derived `Layout Direction`; no DB tables in Phase 3
- `contracts/` — four interface contracts: `locale-cubit`, `app-strings` (FR-008 wrapper), `lint-guard-literals`, `lint-guard-parity`
- `quickstart.md` — end-to-end manual verification recipe (10 steps on the Infinix Note 8); no automated tests

Predecessor (still relevant — Phase 3 builds on top of it):
- [specs/002-design-system/plan.md](specs/002-design-system/plan.md) — design tokens, bilingual font stack (Cairo / IBM Plex Sans Arabic / Inter), Theme Gallery, Palette Tester. Phase 3 reuses `buildAppTheme(palette:, brightness:, locale:)` unchanged.

Cross-cutting: [docs/decisions/0001-secrets-and-pii-storage.md](docs/decisions/0001-secrets-and-pii-storage.md) — Supabase Vault for backend secrets and admin-only PII (lands Phase 4 onward; not a Phase 3 concern).
<!-- SPECKIT END -->
