// Phase 25 premium uplift v2 — publisher summary dashboard.
//
// A role-aware landing surface for approved publishers: a hero header, a
// KPI StatCard grid driven by publisher_dashboard_counts(), and quick-action
// AppDashboardTiles (My Listings, Add Listing, Saved Searches).
//
// Behaviour-preserving + additive: navigates to existing routes only. Token-
// clean (AppColors/AppTextStyles/AppSpacing/appRadius + shared widgets).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/dashboard_tile.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import 'package:alnujom/features/crm/presentation/pages/crm_page.dart';

import '../../../../core/widgets/stat_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/publisher_dashboard_counts.dart';
import '../bloc/publisher_analytics_cubit.dart';
import '../bloc/publisher_dashboard_summary_cubit.dart';
import '../bloc/publisher_dashboard_summary_state.dart';
import '../widgets/publisher_charts_section.dart';
import 'lead_analytics_page.dart';

class PublisherDashboardPage extends StatelessWidget {
  const PublisherDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PublisherDashboardSummaryCubit>(
      create: (_) => getIt<PublisherDashboardSummaryCubit>()..load(),
      child: const _PublisherDashboardView(),
    );
  }
}

class _PublisherDashboardView extends StatelessWidget {
  const _PublisherDashboardView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.publisherDashboardTitle)),
      body: BlocBuilder<
        PublisherDashboardSummaryCubit,
        PublisherDashboardSummaryState
      >(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () =>
                context.read<PublisherDashboardSummaryCubit>().refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                _Header(l10n: l10n),
                const SizedBox(height: AppSpacing.lg),
                _SummarySection(state: state, l10n: l10n),
                if (state is PublisherDashboardSummaryLoaded) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _SectionLabel(label: l10n.publisherChartsSectionLabel),
                  const SizedBox(height: AppSpacing.md),
                  PublisherChartsSection(counts: state.counts),
                ],
                const SizedBox(height: AppSpacing.xl),
                _SectionLabel(label: l10n.publisherDashboardQuickActions),
                const SizedBox(height: AppSpacing.md),
                _QuickActions(l10n: l10n),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A premium gradient-washed hero band that grounds the dashboard identity.
class _Header extends StatelessWidget {
  const _Header({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return StaggeredListItem(
      index: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: appRadius(AppRadii.lg),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              colors.primary.withValues(alpha: 0.14),
              colors.accent.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(color: colors.outline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.14),
              ),
              child: Icon(
                LucideIcons.layout_dashboard,
                color: colors.primary,
                size: AppSpacing.xl,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.publisherDashboardHeaderTitle,
                    style: styles.titleLarge.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.publisherDashboardHeaderSubtitle,
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.state, required this.l10n});

  final PublisherDashboardSummaryState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case PublisherDashboardSummaryLoading():
        return const _StatGridSkeleton();
      case PublisherDashboardSummaryError(:final message):
        return SizedBox(
          height: 240,
          child: ErrorState(
            title: l10n.publisherDashboardSummaryError,
            message: message,
            onRetry: () =>
                context.read<PublisherDashboardSummaryCubit>().refresh(),
          ),
        );
      case PublisherDashboardSummaryLoaded(:final counts):
        return _StatGrid(counts: counts, l10n: l10n);
    }
  }
}

/// The KPI grid: a 2-column responsive grid of [StatCard]s.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.counts, required this.l10n});

  final PublisherDashboardCounts counts;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = NumberFormat.decimalPattern(locale);

    final cards = <Widget>[
      StatCard(
        icon: LucideIcons.list,
        value: fmt.format(counts.totalListings),
        label: l10n.publisherDashboardStatTotalListings,
        accent: colors.primary,
        onTap: () => context.push(AppRoutes.publisherMyListings),
      ),
      StatCard(
        icon: LucideIcons.circle_check_big,
        value: fmt.format(counts.activeListings),
        label: l10n.publisherDashboardStatActiveListings,
        accent: colors.success,
        onTap: () => context.push(AppRoutes.publisherMyListings),
      ),
      StatCard(
        icon: LucideIcons.clock,
        value: fmt.format(counts.pendingListings),
        label: l10n.publisherDashboardStatPendingListings,
        accent: colors.warning,
        onTap: () => context.push(AppRoutes.publisherMyListings),
      ),
      StatCard(
        icon: LucideIcons.circle_x,
        value: fmt.format(counts.rejectedListings),
        label: l10n.publisherDashboardStatRejectedListings,
        accent: colors.error,
        onTap: () => context.push(AppRoutes.publisherMyListings),
      ),
      StatCard(
        icon: LucideIcons.inbox,
        value: fmt.format(counts.totalInquiries),
        label: l10n.publisherDashboardStatTotalInquiries,
        accent: colors.primary,
        onTap: () => context.push(AppRoutes.inquiries),
      ),
      StatCard(
        icon: LucideIcons.message_square,
        value: fmt.format(counts.newInquiries),
        label: l10n.publisherDashboardStatNewInquiries,
        accent: colors.accent,
        onTap: () => context.push(AppRoutes.inquiries),
      ),
      StatCard(
        icon: LucideIcons.trending_up,
        value: fmt.format(counts.leadEventsTotal),
        label: l10n.publisherDashboardStatLeadEvents,
        accent: colors.secondary,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) => StaggeredListItem(
        index: index + 1,
        child: cards[index],
      ),
    );
  }
}

class _StatGridSkeleton extends StatelessWidget {
  const _StatGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) => const LoadingState.card(),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final tiles = <Widget>[
      AppDashboardTile(
        icon: LucideIcons.list_checks,
        title: l10n.myListingsPageTitle,
        subtitle: l10n.publisherDashboardActionMyListingsSubtitle,
        accent: colors.primary,
        onTap: () => context.push(AppRoutes.publisherMyListings),
      ),
      AppDashboardTile(
        icon: LucideIcons.contact,
        title: l10n.dashCrmTileTitle,
        subtitle: l10n.dashCrmTileSubtitle,
        accent: colors.accent,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CrmPage()),
        ),
      ),
      AppDashboardTile(
        icon: LucideIcons.plus,
        title: l10n.publisherDashboardActionAddListing,
        subtitle: l10n.publisherDashboardActionAddListingSubtitle,
        accent: colors.success,
        onTap: () =>
            context.pushNamed(AppRouteNames.publisherListingsCreate),
      ),
      AppDashboardTile(
        icon: LucideIcons.chart_no_axes_column,
        title: l10n.leadAnalyticsTitle,
        subtitle: l10n.publisherDashboardActionLeadAnalyticsSubtitle,
        accent: colors.secondary,
        onTap: () => _openLeadAnalytics(context),
      ),
      AppDashboardTile(
        icon: LucideIcons.bookmark,
        title: l10n.publisherDashboardActionSavedSearches,
        subtitle: l10n.publisherDashboardActionSavedSearchesSubtitle,
        accent: colors.accent,
        onTap: () => context.push(AppRoutes.savedSearches),
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          StaggeredListItem(index: i + 8, child: tiles[i]),
        ],
      ],
    );
  }

  /// Pushes the lead-analytics surface, providing a freshly-resolved
  /// [PublisherAnalyticsCubit] (kicked off via load()). Navigator.push keeps
  /// this additive — no go_router route is introduced.
  void _openLeadAnalytics(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<PublisherAnalyticsCubit>(
          create: (_) => getIt<PublisherAnalyticsCubit>()..load(),
          child: const LeadAnalyticsPage(),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Text(
      label,
      style: styles.titleMedium.copyWith(color: colors.onSurface),
    );
  }
}
