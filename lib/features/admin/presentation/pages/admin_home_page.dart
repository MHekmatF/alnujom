// Phase 20 (spec/020-admin-dashboard) — T010, T015, T019
// AdminHomePage rewritten from a ListView of ListTiles into a permission-gated
// responsive grid.  The `/admin` route + authRedirect guard are UNCHANGED (FR-001).
// NO Timer, NO Realtime subscription (FR-011/FR-020).
// Phase 2 tokens only — no inline hex/font-size/padding literals (FR-017).
// No hardcoded role branches — all gates via PermissionChecker (FR-015).
//
// Phase 25 uplift v2 — restyled into a premium grouped console:
//   • a role-badge identity header (Super Admin / Administrator),
//   • a horizontally-scrolling quick-stats KPI strip (admin_dashboard_counts),
//   • sections grouped under localized headers (Moderation / Configuration /
//     Insights / Super Admin) rendered with the shared AppDashboardTile.
// All permission gating, the RouteAware re-entry reload, the Realtime counter
// channel, and the quick-action deep-links are PRESERVED.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/dashboard_tile.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/ds/dc_quick_link_tile.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../debug/locations_smoke_test_tile.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../analytics/presentation/bloc/admin_analytics_cubit.dart';
import '../../analytics/presentation/pages/admin_analytics_page.dart';
import '../../dashboard/domain/entities/dashboard_counts.dart';
import '../../dashboard/domain/entities/dashboard_section.dart';
import '../../dashboard/presentation/bloc/dashboard_cubit.dart';
import '../../dashboard/presentation/bloc/dashboard_state.dart';
import '../../dashboard/presentation/widgets/admin_quick_stats_row.dart';
import '../../dashboard/presentation/widgets/dashboard_sections.dart';

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

    return DcCrownScaffold(
      title: l10n.admin_home_title,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      actions: const [LocaleToggleAction()],
      body: visibleSections.isEmpty
          ? _EmptyState(l10n: l10n)
          : BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                final counts = state is DashboardLoaded ? state.counts : null;
                final isLoading = state is DashboardLoading;
                final isError = state is DashboardError;

                return RefreshIndicator(
                  onRefresh: () => context.read<DashboardCubit>().refresh(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── Quick-stats KPI strip ───────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.md,
                            bottom: AppSpacing.md,
                          ),
                          child: AdminQuickStatsRow(
                            counts: counts,
                            isLoading: isLoading,
                          ),
                        ),
                      ),
                      // ── Counter error notice (loading shows in the strip) ─
                      if (isError)
                        SliverToBoxAdapter(
                          child: _CounterErrorNotice(
                            l10n: l10n,
                            onRetry: () =>
                                context.read<DashboardCubit>().refresh(),
                          ),
                        ),
                      // ── Grouped sections ────────────────────────────────
                      ..._buildGroupedSlivers(
                        context,
                        visibleSections,
                        counts,
                        l10n,
                      ),
                      // ── Analytics & charts (Navigator.push, not a route) ─
                      // Gated by the union of the analytics RPCs' permissions;
                      // each RPC re-gates server-side, so a partial admin sees
                      // empty charts rather than an error.
                      if (checker.any(const [
                        'listings.view_all',
                        'users.view',
                        'inquiries.view_all',
                      ]))
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: AppSpacing.lg,
                              top: AppSpacing.md,
                              end: AppSpacing.lg,
                            ),
                            child: AppDashboardTile(
                              icon: LucideIcons.chart_no_axes_column,
                              title: l10n.adminAnalyticsTileTitle,
                              subtitle: l10n.adminAnalyticsTileSubtitle,
                              accent: AppColors.of(context).accent,
                              onTap: () => _openAnalytics(context),
                            ),
                          ),
                        ),
                      // ── Debug smoke-test tile (kDebugMode only) ─────────
                      if (kDebugMode)
                        const SliverToBoxAdapter(
                          child: LocationsSmokeTestTile(),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xxl),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// Pushes the admin analytics surface, providing a freshly-resolved
  /// [AdminAnalyticsCubit] (kicked off via load()). Navigator.push keeps this
  /// additive — no go_router route is introduced.
  void _openAnalytics(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<AdminAnalyticsCubit>(
          create: (_) => getIt<AdminAnalyticsCubit>()..load(),
          child: const AdminAnalyticsPage(),
        ),
      ),
    );
  }

  /// Renders the visible sections grouped under localized group headers, in the
  /// canonical group order. Empty groups are skipped.
  List<Widget> _buildGroupedSlivers(
    BuildContext context,
    List<DashboardSection> sections,
    DashboardCounts? counts,
    AppLocalizations l10n,
  ) {
    final slivers = <Widget>[];
    var runningIndex = 0;
    for (final group in DashboardSectionGroup.values) {
      final inGroup = sections.where((s) => s.group == group).toList();
      if (inGroup.isEmpty) continue;

      slivers.add(
        SliverToBoxAdapter(
          child: _GroupHeader(label: _groupLabel(group, l10n)),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.35,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final section = inGroup[index];
              final tile = _buildSectionTile(context, section, counts, l10n);
              return StaggeredListItem(index: runningIndex++, child: tile);
            }, childCount: inGroup.length),
          ),
        ),
      );
    }
    return slivers;
  }

  Widget _buildSectionTile(
    BuildContext context,
    DashboardSection section,
    DashboardCounts? counts,
    AppLocalizations l10n,
  ) {
    final label = _resolveLabel(section.labelKey, l10n);

    // Counter: null = not permitted → omit badge; 0 = permitted, nothing
    // pending. The tile hides badges that are null or <= 0.
    final counter = counts != null
        ? _resolveCounter(section.counterKey, counts)
        : null;

    // Quick-action deep-link: counter tiles route to the filtered queue (FR-009).
    final quickRoute = _quickActionRoute(section.counterKey) ?? section.route!;

    return DcQuickLinkTile(
      icon: section.icon,
      label: label,
      badgeLabel: (counter != null && counter > 0)
          ? formatLocalizedNumber(counter, Localizations.localeOf(context))
          : null,
      // Preserve the Phase 20 navigation behaviour (go_router push).
      onTap: () => context.push(quickRoute),
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

  String _groupLabel(DashboardSectionGroup group, AppLocalizations l10n) {
    return switch (group) {
      DashboardSectionGroup.moderation => l10n.adminSectionGroupModeration,
      DashboardSectionGroup.configuration =>
        l10n.adminSectionGroupConfiguration,
      DashboardSectionGroup.insights => l10n.adminSectionGroupInsights,
      DashboardSectionGroup.superAdmin => l10n.adminSectionGroupSuperAdmin,
    };
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

// ── Group header ──────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        label,
        style: styles.labelLarge.copyWith(color: colors.textMuted),
      ),
    );
  }
}

// ── Counter error notice ──────────────────────────────────────────────────────

class _CounterErrorNotice extends StatelessWidget {
  const _CounterErrorNotice({required this.l10n, required this.onRetry});

  final AppLocalizations l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.triangle_alert, color: colors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.dashboardCountersError,
              style: styles.bodyMedium.copyWith(color: colors.error),
            ),
          ),
          AppButton(
            label: l10n.dashboardCountersRetry,
            variant: AppButtonVariant.text,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ── Empty state (no sections visible for this user) ───────────────────────────

/// Batch-2: the hand-rolled title+body column became the shared [EmptyState],
/// which adds the DS glyph badge and the `Semantics(header:)` on the headline.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.shield,
      headline: l10n.admin_home_empty_title,
      body: l10n.admin_home_empty_body,
    );
  }
}
