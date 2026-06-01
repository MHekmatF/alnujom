// Phase 20 (spec/020-admin-dashboard) — T007
// DashboardSection value object: describes one admin-hub tile.
// Constitution IX: pure Dart, no Supabase import.
import 'package:flutter/material.dart';

/// Whether a dashboard section tile is navigable or shown as coming-soon.
enum DashboardSectionState { enabled, comingSoon }

/// Describes one tile in the admin dashboard grid.
///
/// - [labelKey]       — resolved via AppLocalizations at render time.
/// - [permissionKeys] — any-of gate (PermissionChecker.any / has).
/// - [route]          — AppRoutes.* destination when [state] is [enabled].
/// - [state]          — comingSoon → disabled, non-navigating tile.
/// - [counterKey]     — optional symbolic name for the DashboardCounts field
///                      this tile should display; null means no counter.
/// - [icon]           — Material icon for the tile.
class DashboardSection {
  const DashboardSection({
    required this.labelKey,
    required this.permissionKeys,
    this.route,
    this.state = DashboardSectionState.enabled,
    this.counterKey,
    this.secondaryCounterKey,
    required this.icon,
  });

  final String labelKey;
  final List<String> permissionKeys;
  final String? route;
  final DashboardSectionState state;

  /// Symbolic name for the counter field on [DashboardCounts]:
  /// 'pendingUsers' | 'pendingListings' | 'openReports' |
  /// 'newInquiries24h' | 'activeListings'
  final String? counterKey;

  /// Optional secondary, informational (non-deep-linking) counter field on
  /// [DashboardCounts]. Per the contract, the Listings tile carries
  /// pending_listings as its primary badge AND active_listings as a secondary
  /// caption. Same null/0 semantics: null = not permitted → omit; 0 = render.
  final String? secondaryCounterKey;

  final IconData icon;
}
