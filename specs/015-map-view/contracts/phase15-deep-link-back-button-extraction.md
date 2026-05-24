# Contract: `DeepLinkAwareBackButton` extraction

**Phase**: 15 — Map View
**Owner**: Sub-Phase B (cross-cutting refactor)
**Files**:
- `lib/core/widgets/deep_link_aware_back_button.dart` (CREATE)
- `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE — replace inline `_handleBack`)
- `lib/features/search/presentation/pages/search_page.dart` (UPDATE — replace inline ternary)
**Spec refs**: FR-015
**Research refs**: R-96
**Realizes**: Phase 13 R-71 forward-state + Phase 14 DEFERRED.md §D-001 trigger condition (Phase 15 IS the third consumer)

## Widget definition

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';

/// Phase 13 R-71 / Phase 14 R-? extraction: a back-button widget that pops the
/// in-app navigator when there's a back-stack entry, OR navigates to a
/// fallback route (typically the home route) when the page was entered via
/// deep-link with an empty back-stack.
///
/// Realizes the Phase 13 Q4=D conditional back-button pattern. Phase 15 (MapPage)
/// is the third consumer of the pattern, triggering the extraction per Phase 14
/// DEFERRED.md §D-001.
class DeepLinkAwareBackButton extends StatelessWidget {
  const DeepLinkAwareBackButton({
    super.key,
    this.fallbackRoute = AppRoutes.home,
  });

  /// The route to navigate to when the in-app navigator cannot pop.
  /// Defaults to [AppRoutes.home].
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go(fallbackRoute);
        }
      },
    );
  }
}
```

## Refactor of `listing_details_page.dart`

```dart
// BEFORE:
void _handleBack(BuildContext context) {
  if (Navigator.canPop(context)) {
    Navigator.pop(context);
  } else {
    context.go(AppRoutes.home);
  }
}

@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _handleBack(context);
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
        // ...
      ),
      // ...
    ),
  );
}

// AFTER:
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        // The system back gesture path; the widget itself handles the
        // AppBar tap path below.
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go(AppRoutes.home);
        }
      }
    },
    child: Scaffold(
      appBar: AppBar(
        leading: const DeepLinkAwareBackButton(),
        // ...
      ),
      // ...
    ),
  );
}
```

(The `PopScope.onPopInvokedWithResult` handler stays inline because it handles the system back gesture which has different semantics than the AppBar tap — the widget extraction targets only the IconButton path. A second-pass extraction could fold both into the widget via a `PopScope`-wrapping variant, but Phase 15 keeps the scope narrow.)

## Refactor of `search_page.dart`

```dart
// BEFORE:
appBar: AppBar(
  leading: Navigator.canPop(context)
      ? const BackButton()
      : IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go(AppRoutes.home),
        ),
  // ...
),

// AFTER:
appBar: AppBar(
  leading: const DeepLinkAwareBackButton(),
  // ...
),
```

## Adoption in `MapPage` (Sub-Phase E)

`MapPage` consumes `DeepLinkAwareBackButton` from the start — no inline pattern in the new code:

```dart
Scaffold(
  appBar: AppBar(
    leading: const DeepLinkAwareBackButton(),
    title: Text(l10n.map_page_title),
    actions: const [MapRefreshButton()],
  ),
  // ...
)
```

## Behavioral contract

1. **Identical behavior**: The extracted widget produces the same back behavior as the inline patterns in Phase 13 + Phase 14. No regression.
2. **Configurable fallback**: The `fallbackRoute` parameter defaults to `AppRoutes.home`. Future consumers can override (e.g., a deeply-nested admin page might fall back to `AppRoutes.admin`).
3. **No external state**: The widget reads only `Navigator.canPop(context)` and uses `context.go` — no BLoC, no provider, no controller dependency.
4. **Icon convention**: Always `Icons.arrow_back` (Material directional-mirroring is automatic via `Directionality.of(context)`). NOT `Icons.home` even when the fallback action is "go home" — the user expects a back arrow.

## Acceptance test (manual)

- Open `MapPage` via the home tile → tap back → return to home page.
- Open `MapPage` via cold-launch deep-link (e.g., `am start -W -a android.intent.action.VIEW -d "alnujom://map"` if a deep-link scheme exists, OR simulate by setting `/` as the initial route then `/map`) → tap back → land on home page (no in-app history).
- Open `MapPage` via "View on map" from a listing details page → tap back → return to listing details page.
- Open `MapPage` via "Show on map" from search → tap back → return to search page with filters intact.
- Repeat the cycle for `ListingDetailsPage` and `SearchPage` after refactor to confirm no regression.
