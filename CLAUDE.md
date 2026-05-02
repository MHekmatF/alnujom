<!-- SPECKIT START -->
Active Spec Kit feature: `002-design-system` (Phase 2 — Design System & Theme Tokens)

For technologies, project structure, and shell commands, read the plan:
[specs/002-design-system/plan.md](specs/002-design-system/plan.md)

Companion artifacts in the same folder:
- `spec.md` — user stories, FRs, success criteria, clarifications (Modern Marketplace direction; Modern + Trust palettes; FR-015 production-Modern-only; FR-016 OS-following theme default)
- `research.md` — locked technical decisions (token API, icon library, golden tooling, lint guard, font strategy, palette gating, theme auto-following, naming + radius reconciliations)
- `data-model.md` — `ColorPalette`, `AppThemeMode`, `ComponentState`, preference keys; no DB tables in Phase 2
- `contracts/` — six interface contracts: `design-tokens`, `component-library` (33-file widget catalog), `theme-cubit`, `palette-cubit`, `theme-gallery`, `lint-guard`
- `quickstart.md` — end-to-end verification recipe (10 steps, run on the Infinix Note 8 reference device)

Source design inputs (reference, not edited by this spec):
- [docs/design/decision.md](docs/design/decision.md) — locked Modern Marketplace direction (2026-05-02)
- [docs/design/screens-and-components.md](docs/design/screens-and-components.md) — full screen + component catalog

Cross-cutting: [docs/decisions/0001-secrets-and-pii-storage.md](docs/decisions/0001-secrets-and-pii-storage.md) — Supabase Vault for backend secrets and admin-only PII (lands Phase 4 onward; not a Phase 2 concern).
<!-- SPECKIT END -->
