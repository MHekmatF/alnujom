# Contract: Deep-Link-Aware Back Button (Q4=D)

**Path**: `lib/features/listing_details/presentation/pages/listing_details_page.dart` (inline helper per R-71)
**Implements**: FR-021 (Q4=D wiring), spec Edge Cases (deep-link entry)
**Verifies**: SC-033

## Pattern

```dart
void _handleBack(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    context.go(AppRoutes.home);
  }
}
```

## Wiring

The pattern is wired in TWO places per Q4=D:

1. **AppBar back-arrow IconButton**: `onPressed: () => _handleBack(context)`.
2. **PopScope body wrapper** (for Android system back gesture): `canPop: false` + `onPopInvoked: (didPop) { if (!didPop) _handleBack(context); }`.

The `PopScope` widget is the modern Flutter API (Flutter 3.12+); on older Flutter versions it's `WillPopScope` with `onWillPop: () async { _handleBack(context); return false; }`. Plan-time research at implementation confirms which API is current.

## Behavior matrix

| Entry path | `Navigator.canPop()` | Back action | Result |
|---|---|---|---|
| User tapped a HomePage card | `true` | `Navigator.pop()` | Returns to HomePage at prior scroll position. |
| Future: User tapped a Phase 14 search-result card | `true` (assuming `context.push`) | `Navigator.pop()` | Returns to search results. |
| Future: User tapped a Phase 15 map popover (if it uses `context.push`) | `true` | `Navigator.pop()` | Returns to map. |
| Future: User tapped a Phase 15 map popover (if it uses `context.go`) | `false` | `context.go(AppRoutes.home)` | Routes to HomePage. |
| Deep-link entry (browser paste, future Phase 22 push, future shared-URL receive) | `false` | `context.go(AppRoutes.home)` | Routes to HomePage instead of app exit. |
| Future: User navigated via cold-launch direct intent | `false` | `context.go(AppRoutes.home)` | Routes to HomePage. |

## Forward-state convention

The Q4=D pattern is the FORWARD-STATE CONVENTION for every later-phase page that may be entered via deep-link. Per R-71, Phase 13 ships the pattern as an INLINE helper inside `listing_details_page.dart`. When the SECOND consumer arrives (Phase 14 search-result detail page if it has its own URL; Phase 22 push-notification deep-link targets; etc.), the pattern is extracted to a reusable widget at `lib/core/widgets/deep_link_aware_back_button.dart` (or a `mixin DeepLinkAwareBackMixin`). The Phase 14 / Phase 22 spec MUST cite Q4=D by reference AND adopt either the inline pattern OR the extracted abstraction.

## Verification

### Manual (per SC-033)

1. **In-app navigation case**: launch app to HomePage, tap any listing card, tap AppBar back arrow → confirm return to HomePage at prior scroll position. Repeat with Android system back gesture.
2. **Deep-link entry case**: kill the app, then from a desktop terminal: `adb shell am start -a android.intent.action.VIEW -d "alnujom://listings/<a-real-approved-uuid>" com.alnujom.app` (replace the URI scheme + package per the actual app's manifest). Confirm the app launches directly to `ListingDetailsPage`. Tap AppBar back arrow → confirm route to HomePage (NOT app exit). Repeat with Android system back gesture.

### Grep (per SC-033)

```bash
grep "Navigator.canPop()" lib/features/listing_details/presentation/pages/listing_details_page.dart
# Expected: at least 1 match in the back-handler.

grep "AppRoutes.home" lib/features/listing_details/presentation/pages/listing_details_page.dart
# Expected: at least 1 match (the else branch's go target).

grep "PopScope\|WillPopScope" lib/features/listing_details/presentation/pages/listing_details_page.dart
# Expected: at least 1 match (the body wrapper).
```
