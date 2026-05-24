# Contract: Phase 14 Filter State Persistence

**Pattern**: `SearchBloc` BLoC lifetime preservation via `go_router` page cache
**Sub-Phase**: F (Wave 3) — the BLoC lifetime is a consequence of `SearchPage`'s route placement
**Created**: 2026-05-24

---

## Purpose

Spec FR-012 requires that filter state (active filters + sort order) be preserved when the user navigates from the search page to a listing detail and presses Back. This contract documents the mechanism and its invariants.

---

## Mechanism (R-77)

`SearchPage` creates its `SearchBloc` via `BlocProvider` in the `build` method. Because `SearchPage` is rendered inside a `go_router` `GoRoute`, `go_router` keeps the `Page` object (and its subtree) alive on the `Navigator` stack until the route is fully popped. When the user navigates to `ListingDetailsPage` via `context.go('/listings/:id')`, a new `Page` is pushed on top of the `SearchPage` in the Navigator. The `SearchPage` widget tree — including its `BlocProvider<SearchBloc>` — is not disposed; it stays mounted in the background.

When the user presses Back (`Navigator.pop`), the `ListingDetailsPage` page is removed from the stack and `SearchPage` is restored to the foreground. Because `SearchBloc` was never disposed, `SearchState` (including `filters`, `sort`, `results`, and `cursor`) is exactly as the user left it. No re-fetch is triggered on Back navigation.

---

## Invariants

1. **`BlocProvider` placement**: The `BlocProvider<SearchBloc>` wraps the `SearchPage` widget, not the top-level `app_router.dart` shell. This scopes the BLoC lifetime to the search route's page lifetime.

2. **No `BlocProvider.value` with an external BLoC**: The BLoC is created inside the `BlocProvider`'s `create:` callback — it is owned by the page. It is not injected from outside.

3. **BLoC not closed on route pause**: When `SearchPage` is backgrounded (another route is pushed on top), Flutter does not call `dispose()` on the `BlocProvider` until the route is popped off the Navigator stack. This is the standard `go_router` + BLoC behavior.

4. **Scroll position**: The `ListView` inside `_ResultsListView` preserves its scroll position automatically via Flutter's `ScrollController` (no explicit `PageStorageKey` needed for in-session persistence).

5. **Session scope only**: Per spec Assumptions, filter state persistence is scoped to the current navigation session. If the user navigates to the Home screen (not via Back), then opens Search again, a fresh `SearchPage` is constructed with a new `SearchBloc` and `FilterState.empty`.

---

## Lifecycle Diagram

```
User taps hero search bar
  → context.go('/search')
  → SearchPage pushed on Navigator stack
  → BlocProvider<SearchBloc> created, SearchBloc initialized
  → SearchBloc dispatches SearchFiltersApplied(FilterState.empty)
  → Results load

User taps result card
  → context.go('/listings/abc-123')
  → ListingDetailsPage pushed on Navigator stack
  → SearchPage widget tree remains mounted (not disposed)
  → SearchBloc state: { filters: F, sort: S, results: [...] }  ← untouched

User presses Back
  → ListingDetailsPage popped
  → SearchPage restored to foreground
  → BlocBuilder rebuilds from live SearchBloc state  ← same F, S, results
  → No new network request
```

---

## What Does NOT Trigger a Re-fetch

- Pressing Back from `ListingDetailsPage` to `SearchPage`.
- The app going to the background and returning to the foreground (per Phase 13 Q6=A: no auto-refresh on background→foreground resume — inherited by Phase 14).

---

## What DOES Reset State

- The user taps the Back button from `SearchPage` itself (popping the search route) — `SearchBloc` is disposed.
- The user navigates to the Home screen via the bottom navigation or a programmatic `context.go('/')` — a new `SearchPage` is constructed on the next open.
- The user changes the sort order or applies new filters — BLoC state updates but this is intentional user action.

---

## DeepLinkAwareBackButton

`SearchPage`'s AppBar uses the same `Q4=D` pattern established in Phase 13:

```dart
leading: Navigator.canPop(context)
  ? const BackButton()
  : IconButton(
      icon: const Icon(Icons.home),
      onPressed: () => context.go(AppRoutes.home),
    ),
```

This handles the edge case where a user deep-links directly to `/search` (no prior route on the stack). Per Phase 13 R-71 forward-state convention, this will be extracted to `DeepLinkAwareBackButton` at `lib/core/widgets/deep_link_aware_back_button.dart` when the second consumer is added (Phase 14 is the second consumer — the Phase 13 inline helper can be extracted now or deferred per the team's preference).
