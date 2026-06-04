# Phase 25 — Design-System Refresh & UI Restyle

## Context / Why
Phase 24 shipped a functional, release-hardened `v1.0.0` but with a **placeholder visual identity** (placeholder blue-star icon, baseline theme). This phase refreshes the app's **visual identity + UI/UX quality** into a cohesive, trustworthy, premium-but-accessible look — **without changing behavior**. It is intentionally a separate effort from the release so a visual overhaul isn't tangled with release hardening.

## Principles & constraints (non-negotiable)
- **Token-first (Principle VI):** every visual change flows THROUGH the existing design-token system (`lib/core/theme/*`) — palette, type scale, spacing, radii, shadows, motion. No scattered hardcoded styles; `tool/lint_design_tokens.dart` stays green.
- **Arabic-first / RTL preserved (Principle V):** every restyled surface renders correctly in (light/dark) × (ar-RTL/en-LTR). No l10n regressions (`lint_l10n_parity` + `lint_l10n_literals` green).
- **No behavior change:** purely visual — no feature/logic/routing/data/backend changes. `flutter analyze --fatal-infos` clean; tests pass (golden/contrast baselines intentionally regenerated).
- **Android-first (Principle XI):** verified on the Pixel 8 Pro AVD (Infinix Note 8 when feasible).

## Goal
A cohesive new visual identity applied across the app: refreshed tokens + component themes, restyled hero screens, and new branding (logo, adaptive icon, light/dark splash) replacing the placeholder.

## Success criteria
- **SC-1** New design tokens (palette / type / spacing / radii / shadows / motion) defined + applied app-wide via the theme; token linter green.
- **SC-2** Hero surfaces restyled: home feed + property card, listing detail, search/filters, onboarding/auth, app bar, bottom nav.
- **SC-3** New logo + adaptive launcher icon + light/dark splash shipped (replace the placeholder).
- **SC-4** All 4 (light/dark)×(ar/en) combos render correctly on the AVD; RTL + Arabic-Indic numerals intact.
- **SC-5** `flutter analyze --fatal-infos` clean; design-token + l10n-parity + l10n-literals linters green; tests pass (golden/contrast re-baselined intentionally, with the change reviewed).
- **SC-6** No functional regression (routing, data, auth, every feature behaves as before).

## Approach / tooling
- **Impeccable** (`.claude/skills/impeccable/`) — methodology + design vocabulary (`init` → `document` a DESIGN.md from the current theme → `colorize`/`typeset`/`layout`/`critique`/`polish` per surface). NOTE: its `detect`/live mode are web/HTML-oriented (won't scan `.dart`); for Flutter we use the methodology + the project's token linter + on-AVD verification.
- **Branding** via **Nano Banana Pro** (logo/icon/splash), wired with `flutter_launcher_icons` + `flutter_native_splash`.
- Optional **Figma Make / Claude design** for *visual mockups only* (their code is web, not Flutter — reference, not output).

## Design direction (anchor prompt)
> "Modern, trustworthy mobile UI for **AlNujom (النجوم — 'the stars')**, an **Arabic-first (RTL) Syrian real-estate marketplace**. Mood: trustworthy, calm, premium-but-accessible — not flashy. Cohesive palette (confident primary + neutral surfaces + clear semantic colors), clean type scale, generous spacing, soft rounded cards, subtle depth. Full **light + dark** and **RTL Arabic** support. Avoid AI-slop clichés (purple gradients, glassmorphism overload, generic SaaS look). Output color/type/spacing tokens."

## Implemented design decision (2026-06)
Two full UI/UX designs were generated (Figma Make + Claude design, kept under `UiUX/`). The user chose the **Claude Design** language as AlNujom's identity, with the genuinely-better Figma idea grafted in:
- **Primary:** deep, trustworthy blue `#13507D` (light) / `#6BB0E6` (dark) — supersedes the earlier "keep the bright royal blue" note.
- **Accent:** warm coral `#F4795B` / `#FF8E72` (favorites, CTAs, brand companion star).
- **Trust signal:** a distinct **green** verified-agency badge (`#1F7A4D` / `#57C48C`).
- **Graft from Figma Make:** visually distinct **sale (blue) vs rent (green)** purpose pills.
- **Branding:** a hand-authored two-tone star ("sparkle") mark (`branding/*.svg` → adaptive icon + light/dark splash), matching the in-app `BrandMark`.
- Full token set + the rationale are documented in `DESIGN.md` at the repo root.

## Execution order (token-first → components → screens)
1. **Branding** — logo / adaptive icon / light+dark splash → replace placeholder.
2. **Foundation tokens** — palette, type scale, spacing, radii, shadows, motion (`lib/core/theme/*`).
3. **Component themes** — cards, buttons, chips/category pills, app bar, inputs, dialogs, bottom nav, agency badges, empty/loading/error states.
4. **Hero screens** — home feed + property card (first; highest impact), listing detail, search/filters, onboarding/auth.
5. **Sweep + polish** — remaining screens; impeccable `critique`/`polish`; verify all 4 theme×locale combos on the AVD.

## Out of scope
New features, behavior/logic/routing/data/backend changes, iOS/Web, and the Phase 24 parked ops (Telegram distribution, cold-start baseline, Phase 22 two-device residual — tracked in `docs/release/v1.0.0.md`).
