# Contract: AppRouter

**Layer**: `lib/core/routing/`
**Constitution**: Principle IV (Clean Architecture Flutter)
**Spec requirement**: FR-007
**Library**: `go_router` (research.md Decision 3 — locked for all phases)

## Purpose

Provide a single, declarative routing surface that every later feature uses to declare its routes. Phase 1 wires only the shell home; Phase 5+ adds auth-gated routes via redirect guards; Phase 13 replaces the shell home with the real home.

## Public surface

```dart
// lib/core/routing/app_router.dart

GoRouter buildAppRouter({
  required AppLogger logger,
}) {
  return GoRouter(
    initialLocation: AppRoutes.shellHome,
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(
        path: AppRoutes.shellHome,
        name: AppRouteNames.shellHome,
        builder: (context, state) => const ShellHomePage(),
      ),
    ],
    errorBuilder: (context, state) {
      logger.warning(
        'Unknown route: ${state.uri}',
        error: state.error,
        tag: 'AppRouter',
      );
      return ErrorState(
        title: 'Routing error',
        message: state.error?.toString() ?? 'Unknown route',
      );
    },
  );
}

abstract final class AppRoutes {
  static const shellHome = '/';
  // Future: shellHome stays as '/' until Phase 13 replaces ShellHomePage.
  // Routes added in later phases are added here as `static const`s.
}

abstract final class AppRouteNames {
  static const shellHome = 'shell-home';
}
```

## Rules

- All routes MUST be declared in `app_router.dart`. Features do NOT define their own `GoRouter` instances or push their own `Navigator` routes.
- Path strings MUST live in `AppRoutes`; named-route strings in `AppRouteNames`. Features import these constants — no string literals in feature code.
- Auth gating, deep-link handling, and redirect logic land in later phases. The Phase 1 router has no `redirect` handler.

## Wire-up

- `injection.dart`'s `@module` provider builds the `GoRouter` once at startup and exposes it as a singleton.
- `app.dart`'s `MaterialApp.router` consumes it via `getIt<GoRouter>()`.

## Phase 1 verification

- The integration smoke test `tester.tap`s on the brand mark + verifies it stays on `AppRoutes.shellHome`.
- A manual reviewer can confirm only one route exists by counting `GoRoute(...)` entries in `app_router.dart` (FR-014: no product feature reachable from the shell).
