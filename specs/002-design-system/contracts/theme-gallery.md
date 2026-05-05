# Contract: Theme Gallery (debug-only)

**Status**: Phase 2 deliverable — debug-only surface | **Spec**: [../spec.md](../spec.md) FR-008, FR-009 | **Plan**: [../plan.md](../plan.md)

## Purpose

A single navigable page that exercises every component in the kit (`contracts/component-library.md`) in every applicable state and exposes live switchers for locale (ar / en), theme (light / dark / auto), and palette (Modern / Trust). Used by designers and QA during Phase 2 visual review and by every later feature phase to verify that no regression has crept into a shared component. Tree-shaken from release builds (FR-009).

## Surface

```
// lib/debug/theme_gallery_page.dart
class ThemeGalleryPage extends StatelessWidget {
  const ThemeGalleryPage({super.key});
  @override
  Widget build(BuildContext context);
}
```

Route registration (in `lib/core/routing/app_router.dart`):

```dart
if (kDesignToolsEnabled) {
  routes.add(GoRoute(
    path: '/_debug/theme-gallery',
    builder: (_, __) => const ThemeGalleryPage(),
  ));
}
```

The `if (kDesignToolsEnabled)` guard sits around the route registration AND the import. With `const bool kDesignToolsEnabled = false` in release, the import statement falls in dead code and Dart's tree-shaker drops the entire `lib/debug/` subtree from the release bundle.

## Required content

The page MUST render, for each entry in `contracts/component-library.md`, every applicable state from `ComponentState`. Layout: top-of-screen control bar with three switchers; below, a long scrollable list of labeled component examples grouped by category (App chrome / Inputs / Cards / Badges / Sheets / Dialogs / Feedback / Media / Chat / Price / Bottom nav / Palette tester).

**Switchers** (top of page):

- **Locale**: pill-segmented `ar` / `en`. Tap → updates `LocaleCubit` for the gallery sub-tree only (or the whole app — implementation choice; behavior MUST update text direction and font family within ≤ 1 frame).
- **Theme**: pill-segmented `auto` / `light` / `dark`. Tap → updates `ThemeCubit`.
- **Palette**: pill-segmented `Modern` / `Trust`. Tap → updates `PaletteCubit`. (This duplicates the `PaletteTester` chip's behavior; the gallery page may use the same cubit so the chip and the segmented control stay in sync.)

**Component sections**: each section header uses `headlineMedium`. Each component example shows the component name, its variant (if any), and renders every applicable state side-by-side or stacked with a small label for each state.

## Invariants

1. The page MUST render correctly with no exceptions in all 8 environment combinations (Modern × Light/Dark × ar/en + Trust × Light/Dark × ar/en).
2. Switching locale / theme / palette MUST cause a visible re-render within one frame; no full-page reload, no app restart.
3. The page MUST NOT be reachable in release builds — neither via deep link, nor via in-app navigation, nor via debug console. Verified by the route registration guard AND by the tree-shake assertion in `quickstart.md` step 8.
4. The page MUST NOT depend on Supabase, network, or any backend service. All component examples render with hard-coded sample data so the page works offline.

## Test surface

- A widget test (`test/widgets/theme_gallery_test.dart`) that mounts the page in each of the 4 base combinations (light × ar, light × en, dark × ar, dark × en) under the Modern palette and asserts: no exceptions, every component-section header renders, the switchers are tappable.
- The release-mode tree-shake check is verified end-to-end in `quickstart.md` (no automated assertion in `flutter test` — this is a build-output property).

## Files

- `lib/debug/theme_gallery_page.dart` — the page itself.
- `lib/core/routing/app_router.dart` — route registration guarded by `kDesignToolsEnabled`.
- `lib/core/flags/app_flags.dart` — declares `kDesignToolsEnabled`.

## Out of scope

- Navigation from the production app's home / settings to this page. The page is reached via `/_debug/theme-gallery` directly (or via a debug-only tile if a debug menu is added in a later phase).
- Per-component playground controls (e.g., tweaking a button's loading state via a switch). The page shows static state matrices; interactive playgrounds belong to a follow-up.
- Capturing goldens from this page. Goldens are captured per-component (see `component-library.md` test surface), not from the gallery.
