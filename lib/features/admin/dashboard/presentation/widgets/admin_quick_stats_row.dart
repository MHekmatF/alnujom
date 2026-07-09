// Phase 25 uplift v2 — admin quick-stats row.
//
// A horizontally-scrolling band of [StatCard]s surfacing the operational
// counters from admin_dashboard_counts() (pending users, pending listings,
// open reports, new inquiries, active listings). Each StatCard is only rendered
// when the corresponding counter is permitted (non-null) — preserving the
// FR-010 null/0 semantics. Tapping a stat deep-links to its filtered queue.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/widgets/loading_state.dart';
import '../../../../../core/widgets/stat_card.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/util/localized_numbers.dart';
import '../../domain/entities/dashboard_counts.dart';

/// Fixed width for each stat card in the scrolling row so the cards read as a
/// consistent KPI strip on phones.
const double _kStatCardWidth = 156;

class AdminQuickStatsRow extends StatelessWidget {
  const AdminQuickStatsRow({
    required this.counts,
    required this.isLoading,
    super.key,
  });

  /// Null while the first load is in flight; non-null once loaded (fields may
  /// still be null = not permitted).
  final DashboardCounts? counts;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    if (isLoading && counts == null) {
      return const _StatsRowSkeleton();
    }
    final c = counts;
    if (c == null) return const SizedBox.shrink();

    final cards = <Widget>[
      if (c.pendingUsers != null)
        _stat(
          context,
          icon: LucideIcons.user,
          value: formatLocalizedNumber(c.pendingUsers!, locale),
          label: l10n.adminQuickStatPendingUsers,
          accent: colors.warning,
          route: AppRoutes.adminApprovals,
        ),
      if (c.pendingListings != null)
        _stat(
          context,
          icon: LucideIcons.file_clock,
          value: formatLocalizedNumber(c.pendingListings!, locale),
          label: l10n.adminQuickStatPendingListings,
          accent: colors.warning,
          route: AppRoutes.adminListingReviewPending,
        ),
      if (c.openReports != null)
        _stat(
          context,
          icon: LucideIcons.flag,
          value: formatLocalizedNumber(c.openReports!, locale),
          label: l10n.adminQuickStatOpenReports,
          accent: colors.error,
          route: AppRoutes.adminReports,
        ),
      if (c.newInquiries24h != null)
        _stat(
          context,
          icon: LucideIcons.inbox,
          value: formatLocalizedNumber(c.newInquiries24h!, locale),
          label: l10n.adminQuickStatNewInquiries,
          accent: colors.primary,
          route: AppRoutes.adminInquiries,
        ),
      if (c.activeListings != null)
        _stat(
          context,
          icon: LucideIcons.circle_check_big,
          value: formatLocalizedNumber(c.activeListings!, locale),
          label: l10n.adminQuickStatActiveListings,
          accent: colors.success,
          route: AppRoutes.adminListingReviewPending,
        ),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
        ),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) => cards[index],
      ),
    );
  }

  Widget _stat(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color accent,
    required String route,
  }) {
    return SizedBox(
      width: _kStatCardWidth,
      child: StatCard(
        icon: icon,
        value: value,
        label: label,
        accent: accent,
        onTap: () => context.push(route),
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
        ),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) => const SizedBox(
          width: _kStatCardWidth,
          child: LoadingState.card(),
        ),
      ),
    );
  }
}
