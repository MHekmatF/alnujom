// lib/features/notifications/domain/entities/notification_deep_link.dart
//
// Phase 22 — Resolved target descriptor produced from NotificationType + params.
// The deep-link resolver (PN, T031) maps this to a go_router navigation call.

/// Describes the navigation target for a notification tap.
///
/// Produced by `notification_deep_link_resolver.dart` (PN phase).
/// Carrying a dedicated entity keeps the resolver testable and decoupled from
/// the routing layer.
class NotificationDeepLink {
  const NotificationDeepLink({
    required this.route,
    this.pathParams = const {},
    this.queryParams = const {},
  });

  /// Named go_router route (e.g. `AppRoutes.notifications`).
  final String route;

  /// Path parameters (e.g. `{'id': '<listing_uuid>'}` for detail routes).
  final Map<String, String> pathParams;

  /// Optional query parameters for routes that accept them.
  final Map<String, String> queryParams;

  /// Convenience: `true` when the resolver found a valid navigation target.
  bool get isResolved => route.isNotEmpty;

  @override
  String toString() =>
      'NotificationDeepLink(route: $route, pathParams: $pathParams)';
}
