# Research: Design System & Theme Tokens

**Date**: 2026-05-02 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

This file records the locked technical decisions that drive Phase 2. Each entry follows **Decision / Rationale / Alternatives considered**. Resolved questions feed `plan.md` Technical Context and the contracts in `contracts/`.

---

## R-01 Token API surface

**Decision**: Typed wrapper classes per token category — `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadii`, `AppElevation`. Color and typography wrappers expose a `.of(BuildContext context)` lookup that resolves through `Theme.of(context)` so the active palette + theme dictate the value. Spacing, radii, and elevation wrappers expose `static const` numeric values (palette-agnostic).

**Rationale**: A `BuildContext`-bound API for color and typography makes palette/theme switches declarative — a widget never asks "which palette am I in?", it asks `AppColors.of(context).primary`. Spacing/radii/elevation never vary by palette, so a static API costs nothing and avoids needless `BuildContext` plumbing.

**Alternatives considered**:
- Raw `BuildContext` extensions (`context.colors.primary`) — too implicit; loses IDE jump-to-definition for the token catalog.
- A single global `Tokens` class — collapses unrelated concerns and re-introduces the tokens-everywhere anti-pattern Constitution VI calls out.
- Material `ThemeExtension<T>` only — works for color, but verbose for the cross-cutting needs (e.g., palette-aware `ColorScheme`).

---

## R-02 Icon library

**Decision**: `flutter_lucide` (Lucide via Flutter), pinned at the latest stable. Single icon library across the entire app.

**Rationale**: `screens-and-components.md` §3.1 locks Lucide. Stroke-2-px-at-24-dp aligns with the marketplace catalog (vs Material's hairline icons) and avoids the Material/Cupertino mix Constitution XI's Android focus might otherwise enable.

**Alternatives considered**:
- Material Icons — visual mismatch with the comp; encourages mixing with custom SVGs.
- Hand-authored SVG asset set — costs maintenance, no benefit at this catalog size.
- `flutter_feather_icons` — close to Lucide visually but a smaller, less-maintained set.

---

## R-03 Golden test tooling

**Decision**: Built-in `flutter_test` `matchesGoldenFile`, paired with the standard `flutter test --update-goldens` workflow. No additional package.

**Rationale**: Q1 (clarification) capped Phase 2 visual-regression coverage at `PropertyCard` × 4 environment combinations = 4 images. The built-in matcher is sufficient at this scope; adding a dependency for 4 goldens is over-engineering.

**Alternatives considered**:
- `golden_toolkit` — useful for device-pixel-ratio matrices, multi-device snapshots, and font-loading helpers; none of those needs apply at the Phase 2 floor and the package is officially in maintenance mode.
- `alchemist` — same overhead reasoning as `golden_toolkit`.

---

## R-04 Lint guard implementation

**Decision**: Standalone Dart script at `tool/lint_design_tokens.dart`, invoked via `dart run tool/lint_design_tokens.dart`. CI runs the script as a build step; a thin widget-test wrapper (`test/lint/design_tokens_lint_test.dart`) runs the same logic so local `flutter test` catches violations pre-push.

**Rationale**: FR-007 only needs three banned patterns flagged: raw `Color(0xff…)`, raw `TextStyle(` in feature code, raw integer-literal padding/margin/radius arguments outside the design-system files. `dart:io` + a few regex passes does this in well under 100 lines. Custom-lint setups carry significant boilerplate and constrain CI image choice.

**Alternatives considered**:
- `custom_lint` package — heavier setup, plugin lifecycle, IDE integration none of which Phase 2 needs.
- Pure regex via `grep`/`rg` from a shell script — non-portable across CI agents; harder to evolve as the allow-list grows.
- `dart_code_metrics` — broader linter; includes opinionated rules we'd need to disable.

---

## R-05 Font asset strategy

**Decision**: Vendor full Cairo, IBM Plex Sans Arabic, and Inter at four weights each (Regular/Medium/SemiBold/Bold) — twelve TTF files total under `assets/fonts/`, declared in `pubspec.yaml`.

**Rationale**: FR-010 requires offline-identical rendering. Full vendoring is the simplest path. APK-size impact (estimated 4–8 MB) sits below the Phase 24 release-polish threshold where size optimization is treated as a product concern.

**Alternatives considered**:
- Subsetting to Arabic + Latin glyph ranges only — saves ~2–4 MB; deferred to a follow-up because it adds a build step (`pyftsubset` or `fonttools`) and risks missing edge characters in user-generated content (listing titles, prices) until proven safe.
- `google_fonts` runtime fetch — violates FR-010 (offline render parity) and Constitution's offline expectation.
- Single weight per family — kills the typography catalog (display = 700, body = 400, label = 500).

**Follow-up**: Phase 24 release polish revisits subsetting with measured APK numbers from the reference device.

---

## R-06 Palette persistence layer

**Decision**: Reuse the Phase 1 `PreferencesStore` interface (`specs/001-project-foundation/contracts/preferences-store.md`). Add two new key constants — `app.theme_mode` (always persisted) and `app.palette` (persisted only when `kDesignToolsEnabled` is true). No new persistence abstraction.

**Rationale**: `PreferencesStore` is the project's single typed key/value store contract for app preferences. Splitting palette persistence into a separate `PaletteStore` adds a file and an interface for one extra key.

**Alternatives considered**:
- Standalone `PaletteStore` interface — one-call surface; not worth the file count.
- `shared_preferences` direct read in `PaletteCubit` — bypasses the project's secure storage and Phase 1's typed contract.

---

## R-07 Design-tools gating mechanism

**Decision**: A single build-time constant — `const bool kDesignToolsEnabled = bool.fromEnvironment('DESIGN_TOOLS', defaultValue: false);` — declared in `lib/core/flags/app_flags.dart`. The same constant gates BOTH the Palette Tester chip AND the Theme Gallery surface; they are two parts of one design-tools surface and ship together. Debug / internal-QA builds pass `--dart-define=DESIGN_TOOLS=true`; release builds omit the flag and default to `false`.

**Rationale**: A `const bool` known at compile time enables dead-code elimination — Dart's tree-shaker drops the Palette Tester widget, the Theme Gallery page, their assets, and their imports from the release bundle. FR-009 and FR-015 explicitly demand this; a runtime feature flag cannot satisfy them. Collapsing to a single flag (rather than parallel `kPaletteTesterEnabled` + `kDesignToolsEnabled` constants) eliminates the confused state where, e.g., the cubit accepts cycles + persists but no chip renders.

**Alternatives considered**:
- Two parallel flags (`kPaletteTesterEnabled` + `kDesignToolsEnabled`) — admits the confused state above; rejected on simplicity grounds during /speckit-analyze remediation.
- Runtime feature flag (e.g., remote config, env-injected at runtime) — cannot tree-shake; chip is shipped to end users; FR-015 violation.
- Separate debug-only entry point (`lib/main_debug.dart`) — heavier separation; loses single-binary review.
- Build flavors (`flutter build apk --flavor`) — doable but adds gradle complexity for one binary axis.

---

## R-08 Theme-mode auto-following implementation

**Decision**: When `ThemeCubit` state is `auto`, the rendered theme is selected by reading `MediaQuery.platformBrightnessOf(context)` at the `MaterialApp` level via the `themeMode: ThemeMode.system` setting on `MaterialApp.router`. Cubit emits `auto` / `light` / `dark` purely as the user's choice; live OS-theme changes propagate through Flutter's built-in `WidgetsBindingObserver`/`MediaQuery` rebuild path with no extra plumbing.

**Rationale**: Flutter already handles `ThemeMode.system` correctly — a `MediaQuery` rebuild on OS-theme change re-evaluates `themeMode` and swaps `theme` ↔ `darkTheme`. FR-016's "without app restart" requirement is satisfied by the framework. The cubit's responsibility is solely to translate the persisted user choice into a `ThemeMode` value passed to `MaterialApp`.

**Alternatives considered**:
- Custom `WidgetsBindingObserver` that explicitly emits `Brightness.dark`/`light` to the cubit — duplicates what `ThemeMode.system` does for free.
- `Brightness`-aware listener at app boot only (no live update) — fails FR-016's "live without restart" clause.

---

## R-09 Component naming reconciliation

**Decision**: The canonical name for the listing visual is **`PropertyCard`**, defined in `lib/core/widgets/property_card.dart`. The feature-shared name **`ListingCard`** referenced in `IMPLEMENTATION_PLAN.md` §Phase 2 ships as a thin re-export under `lib/shared/presentation/widgets/listing_card.dart` — a one-line `export 'package:alnujom/core/widgets/property_card.dart';` plus a typedef.

**Rationale**: `PropertyCard` is the more precise term — it covers all property types (apartment, house, shop, office, land, farm), not only listings. `ListingCard` is the feature-layer name future phases (search results, my listings, favorites) will reach for. A shim keeps both names usable without two implementations to maintain.

**Alternatives considered**:
- One name only (`ListingCard`) — drops the more precise term; rejects `screens-and-components.md` §5.5.
- One name only (`PropertyCard`) — forces every feature-phase author to remember the rename; contradicts `IMPLEMENTATION_PLAN.md`.
- Two parallel implementations — guaranteed drift.

## R-09b Generic `AppCard` is dropped — typed cards only

**Decision**: Phase 2 does **not** ship a generic `AppCard` primitive. The kit ships the typed cards `PropertyCard` (vertical + horizontal), `OfficeCard`, and `AdminListItem` directly composed from design-token primitives (`AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadii`, `AppElevation`). No shared abstract `AppCard` widget exists.

**Rationale**: `screens-and-components.md` §5 enumerates only typed cards — no generic card component is described. The `AppCard` mention in `docs/IMPLEMENTATION_PLAN.md` §Phase 2 was an early stub that pre-dated the screens-and-components catalog; carrying both a generic `AppCard` and the typed cards forward would either (a) duplicate visual treatment, or (b) force the typed cards to be wrappers over a generic that does not match any actual screen. Neither earns its weight.

**Alternatives considered**:
- Ship `AppCard` as a generic `Container`-wrapped primitive — adds a layer of indirection that no screen needs.
- Ship `AppCard` as the abstract base of `PropertyCard` / `OfficeCard` — possible but premature; if a third typed card later wants to share more structure, that refactor is cheap and motivated by real shared code, not speculation.

**Implication**: `docs/IMPLEMENTATION_PLAN.md` §Phase 2 widget list is amended to drop `AppCard`. The Phase 2 plan, contracts, and tasks already reflect the typed-cards-only direction.

---

## R-10 Radius scale reconciliation

**Decision**: Adopt the `screens-and-components.md` §2.5 scale: `sm 8 / md 12 / lg 16 / xl 20 / pill 999`. Cards default to `md` (12); buttons default to `md` (12), or `pill` for filter chips; sheets use `xl` (20) top corners; dialogs use `lg` (16).

**Rationale**: `decision.md` §"Note" explicitly recommends adopting the screens-and-components scale because it matches the Figma comp the team is reviewing. The legacy scale in `decision.md` (`sm 4 / md 8 / lg 12 / xl 16 / pill 999`) was an early stub.

**Alternatives considered**:
- Keep `decision.md` legacy scale — contradicts both the comp and the recommendation embedded in that very document.
- Mid-point scale (`sm 6 / md 10 / lg 14 / xl 18`) — invented value with no source; rejected by Constitution XII.

---

## Resolved clarifications recap

| Clarification | Source | Resolution |
|---|---|---|
| Visual-regression scope | spec `## Clarifications` Q1 | `PropertyCard` only (4 goldens) — Phase 2 floor. |
| End-user palette control in production | spec `## Clarifications` Q2 + FR-015 | Production renders Modern only; no Settings row, no gesture, no deep link. |
| Default theme mode behavior | spec `## Clarifications` Q3 + FR-016 | First launch follows OS theme (`auto`); user override persists. |
| Radius scale | spec `## Assumptions` + R-10 | Screens-and-components scale wins. |
| `ListingCard` vs `PropertyCard` | spec `## Assumptions` + R-09 | `PropertyCard` is canonical; `ListingCard` is a re-export shim. |

## Deferred (acceptable as Phase 2 unknowns)

- **Font subsetting** (R-05) — revisit at Phase 24 release polish with measured APK numbers from the reference device.
- **Visual-regression coverage expansion beyond `PropertyCard`** — tracked separately; will surface organically as feature phases reveal which other components are most-rendered or most-edited.

Both deferred items are explicitly low-impact in Phase 2 and have a known re-evaluation point.
