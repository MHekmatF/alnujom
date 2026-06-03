<!-- SPECKIT START -->
Active Spec Kit feature: `025-ui-restyle` (Phase 25 — Design-system refresh & UI restyle)

Read the spec: [specs/025-ui-restyle/spec.md](specs/025-ui-restyle/spec.md).

A **purely visual** restyle — NO behavior/logic/routing/data/backend change — flowing THROUGH the existing design-token system (`lib/core/theme/*`: palette, type scale, spacing, radii, shadows, motion). Preserves Arabic-first RTL + light/dark (Principle V) and stays token-clean (`tool/lint_design_tokens.dart` green — Principle VI). New branding (logo / adaptive icon / light+dark splash) replaces the Phase-24 placeholder blue star.

Execution order: (1) branding (Nano Banana Pro → `flutter_launcher_icons`/`flutter_native_splash`); (2) foundation tokens; (3) component themes (cards, buttons, chips, app bar, inputs, dialogs, bottom nav, badges, empty/loading/error states); (4) hero screens (home + property card first, then listing detail, search/filters, onboarding/auth); (5) sweep + polish. Verify each surface on the Pixel 8 Pro AVD across (light/dark)×(ar/en); the `property_card` golden + `color_scheme_contrast` test baselines are re-generated intentionally (review the diff).

Tooling: the **Impeccable** design skill (`.claude/skills/impeccable/`) for methodology + design vocabulary (init → document a DESIGN.md from the current theme → colorize/typeset/layout/critique/polish per surface). Its `detect`/live mode are web/HTML-oriented (won't scan `.dart`), so for Flutter we use the methodology + the project's token/l10n linters + on-AVD verification. Optional Figma Make / Claude design = visual mockups only (web output, not Flutter).

Predecessor: Phase 24 (`024-release-polish`, merged to `main` via PR #40) shipped the release-hardened `v1.0.0` with a placeholder identity; this phase restyles it. Parked Phase-24 ops (Telegram distribution, cold-start baseline, Phase-22 two-device residual) are tracked in `docs/release/v1.0.0.md` — OUT of scope here.
<!-- SPECKIT END -->
