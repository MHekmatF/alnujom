// Phase 20 (spec/020-admin-dashboard) — T010, T015, T019
// AdminHomePage rewritten from a ListView of ListTiles into a permission-gated
// responsive grid.  The `/admin` route + authRedirect guard are UNCHANGED (FR-001).
// NO Timer, NO Realtime subscription (FR-011/FR-020).
// Phase 2 tokens only — no inline hex/font-size/padding literals (FR-017).
// No hardcoded role branches — all gates via PermissionChecker (FR-015).
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../debug/locations_smoke_test_tile.dart';
import '../../../../l10n/app_localizations.dart';
import '../../dashboard/domain/entities/dashboard_counts.dart';
import '../../dashboard/domain/entities/dashboard_section.dart';
import '../../dashboard/presentation/bloc/dashboard_cubit.dart';
import '../../dashboard/presentation/bloc/dashboard_state.dart';
import '../../dashboard/presentation/widgets/coming_soon_tile.dart';
import '../../dashboard/presentation/widgets/dashboard_sections.dart';
import '../../dashboard/presentation/widgets/dashboard_tile.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardCubit>(
      create: (_) => getIt<DashboardCubit>()..load(),
      child: const _AdminHomeView(),
    );
  }
}

class _AdminHomeView extends StatefulWidget {
  const _AdminHomeView();

  @override
  State<_AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<_AdminHomeView> with RouteAware {
  // On-re-entry reload: subscribe to RouteObserver to reload counts
  // when the user pops back to this screen from a child route (FR-011).
  RouteObserver<ModalRoute<void>>? _routeObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = _resolveRouteObserver();
    if (observer != null && observer != _routeObserver) {
      _routeObserver?.unsubscribe(this);
      _routeObserver = observer;
      final route = ModalRoute.of(context);
      if (route != null) observer.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _routeObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Reload counters when a child route is popped and this page re-appears.
    if (mounted) context.read<DashboardCubit>().refresh();
  }

  RouteObserver<ModalRoute<void>>? _resolveRouteObserver() {
    try {
      if (getIt.isRegistered<RouteObserver<ModalRoute<void>>>()) {
        return getIt<RouteObserver<ModalRoute<void>>>();
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final checker = getIt<PermissionChecker>();

    // Filter sections to only those the current user has any permission for.
    final visibleSections = kDashboardSections
        .where((s) => checker.any(s.permissionKeys))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.admin_home_title),
        actions: const [LocaleToggleAction()],
      ),
      body: visibleSections.isEmpty
          ? _EmptyState(l10n: l10n)
          : BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                final counts =
                    state is DashboardLoaded ? state.counts : null;
                final isLoading = state is DashboardLoading;
                final isError = state is DashboardError;

                return RefreshIndicator(
                  onRefresh: () => context.read<DashboardCubit>().refresh(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── Counter status bar ─────────────────────────────
                      if (isLoading || isError)
                        SliverToBoxAdapter(
                          child: _CounterStatusBar(
                            isLoading: isLoading,
                            isError: isError,
                            l10n: l10n,
                            onRetry: () =>
                                context.read<DashboardCubit>().refresh(),
                          ),
                        ),
                      // ── Dashboard grid ─────────────────────────────────
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 1.0,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildSectionTile(
                              context,
                              visibleSections[index],
                              counts,
                              l10n,
                            ),
                            childCount: visibleSections.length,
                          ),
                        ),
                      ),
                      // ── Debug smoke-test tile (kDebugMode only) ────────
                      if (kDebugMode)
                        const SliverToBoxAdapter(
                          child: LocationsSmokeTestTile(),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionTile(
    BuildContext context,
    DashboardSection section,
    DashboardCounts? counts,
    AppLocalizations l10n,
  ) {
    final label = _resolveLabel(section.labelKey, l10n);

    if (section.state == DashboardSectionState.comingSoon) {
      return ComingSoonTile(
        icon: section.icon,
        label: label,
        comingSoonLabel: l10n.dashboardComingSoon,
      );
    }

    // Counter: null = not permitted → omit badge; 0 = permitted, nothing pending.
    final counter =
        counts != null ? _resolveCounter(section.counterKey, counts) : null;

    // Secondary informational counter (contract: the Listings tile carries
    // pending_listings as its badge AND active_listings as a caption).
    final secondaryCounter = counts != null
        ? _resolveCounter(section.secondaryCounterKey, counts)
        : null;
    final secondaryCounterLabel = section.secondaryCounterKey == 'activeListings'
        ? l10n.dashboardCounterActiveListings
        : null;

    // Quick-action deep-link: counter tiles route to the filtered queue (FR-009).
    final quickRoute =
        _quickActionRoute(section.counterKey) ?? section.route!;

    return DashboardTile(
      icon: section.icon,
      label: label,
      route: quickRoute,
      counter: counter,
      secondaryCounter: secondaryCounter,
      secondaryCounterLabel: secondaryCounterLabel,
    );
  }

  /// Maps symbolic counter key → DashboardCounts field.
  int? _resolveCounter(String? key, DashboardCounts counts) {
    switch (key) {
      case 'pendingUsers':
        return counts.pendingUsers;
      case 'pendingListings':
        return counts.pendingListings;
      case 'openReports':
        return counts.openReports;
      case 'newInquiries24h':
        return counts.newInquiries24h;
      case 'activeListings':
        return counts.activeListings;
      default:
        return null;
    }
  }

  /// Quick-action deep-link per counter (FR-009).
  /// pending_listings → adminListingReviewPending; open_reports → adminReports;
  /// pending_users → adminApprovals; new_inquiries_24h → adminInquiries.
  String? _quickActionRoute(String? counterKey) {
    switch (counterKey) {
      case 'pendingUsers':
        return AppRoutes.adminApprovals;
      case 'pendingListings':
        return AppRoutes.adminListingReviewPending;
      case 'openReports':
        return AppRoutes.adminReports;
      case 'newInquiries24h':
        return AppRoutes.adminInquiries;
      default:
        return null;
    }
  }

  /// Maps DashboardSection.labelKey → localized string.
  String _resolveLabel(String labelKey, AppLocalizations l10n) {
    switch (labelKey) {
      case 'admin_tile_account_approvals':
        return l10n.admin_tile_account_approvals;
      case 'adminTilePendingReview':
        return l10n.adminTilePendingReview;
      case 'admin_tile_reports':
        return l10n.admin_tile_reports;
      case 'admin_tile_agencies':
        return l10n.admin_tile_agencies;
      case 'dashboardTileInquiries':
        return l10n.dashboardTileInquiries;
      case 'locationsTileTitle':
        return l10n.locationsTileTitle;
      case 'adminHomeCurrenciesTile':
        return l10n.adminHomeCurrenciesTile;
      case 'adminTileSuperAdmin':
        return l10n.adminTileSuperAdmin;
      case 'dashboardTileAuditLogs':
        return l10n.dashboardTileAuditLogs;
      case 'dashboardTileAds':
        return l10n.dashboardTileAds;
      case 'dashboardTileSettings':
        return l10n.dashboardTileSettings;
      default:
        return labelKey;
    }
  }
}

// ── Counter status bar ────────────────────────────────────────────────────────

class _CounterStatusBar extends StatelessWidget {
  const _CounterStatusBar({
    required this.isLoading,
    required this.isError,
    required this.l10n,
    required this.onRetry,
  });

  final bool isLoading;
  final bool isError;
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const SizedBox(
              width: AppSpacing.lg,
              height: AppSpacing.lg,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.dashboardCountersLoading,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    // isError
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            size: AppSpacing.lg,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.dashboardCountersError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(l10n.dashboardCountersRetry),
          ),
        ],
      ),
    );
  }
}

// ── Empty state (no sections visible for this user) ───────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.admin_home_empty_title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.admin_home_empty_body,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
