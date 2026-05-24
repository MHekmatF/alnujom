import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';

/// Phase 13 R-71 / Phase 14 DEFERRED §D-001 extraction: a back-button widget
/// that pops the in-app navigator when there is a back-stack entry, OR
/// navigates to a fallback route (typically the home route) when the page was
/// entered via deep-link with an empty back-stack.
///
/// Realizes the Phase 13 Q4=D conditional back-button pattern. Phase 15
/// (MapPage) is the third consumer of the pattern, triggering the extraction
/// per Phase 14 DEFERRED.md §D-001.
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
