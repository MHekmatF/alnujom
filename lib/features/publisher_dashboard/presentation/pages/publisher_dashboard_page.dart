// DC "Blue Crown" (035 v3) — publisher summary dashboard.
//
// A role-aware landing surface for approved publishers, restyled to the DC
// "Blue Crown" system (`AlNujom - Publisher.dc.html`): a bespoke crown identity
// header (agency name + verified tick + notifications bell) over a white sheet
// carrying a 2×2 flat KPI grid (DcStatCard), a single-hue interactions bar chart
// (DcBarChart), and a tonal quick-link grid (DcQuickLinkTile).
//
// Behaviour-preserving: navigates to existing routes only; KPI values come from
// publisher_dashboard_counts() and the chart from the existing charts cubit — no
// fabricated views/response-rate/trend data. Token-clean + Arabic-first RTL.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/charts/dc_bar_chart.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/ds/dc_quick_link_tile.dart';
import '../../../../core/widgets/ds/dc_stat_card.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import 'package:alnujom/features/crm/presentation/pages/crm_page.dart';
import 'package:alnujom/features/viewings/presentation/cubit/viewings_cubit.dart';
import 'package:alnujom/features/viewings/presentation/pages/viewings_list_page.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/publisher_dashboard_counts.dart';
import '../bloc/publisher_analytics_cubit.dart';
import '../bloc/publisher_charts_cubit.dart';
import '../bloc/publisher_charts_state.dart';
import '../bloc/publisher_dashboard_summary_cubit.dart';
import '../bloc/publisher_dashboard_summary_state.dart';
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
    final authState = getIt<AuthBloc>().state;
    final name = authState is Authenticated
        ? (authState.profile.fullName?.trim().isNotEmpty ?? false
              ? authState.profile.fullName!.trim()
              : l10n.publisherDashboardTitle)
        : l10n.publisherDashboardTitle;

    return DcCrownScaffold(
      title: l10n.publisherDashboardTitle,
      titleWidget: _CrownIdentity(
        name: name,
        subtitle: l10n.publisherDashboardCrownSubtitle,
      ),
      actions: [
        DcCrownIconButton(
          icon: Icons.notifications_none,
          onTap: () => context.push(AppRoutes.notifications),
        ),
      ],
      body:
          BlocBuilder<
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
                    _SummarySection(state: state, l10n: l10n),
                    if (state is PublisherDashboardSummaryLoaded) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const _InteractionsChart(),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _ManageSectionLabel(label: l10n.publisherManageSection),
                    const SizedBox(height: AppSpacing.md),
                    _QuickLinks(l10n: l10n, state: state),
                  ],
                ),
              );
            },
          ),
    );
  }
}

/// The bespoke crown title: a storefront avatar chip + the publisher's name (with
/// a verified tick) over a "verified agent" subtitle, all in white on the crown.
class _CrownIdentity extends StatelessWidget {
  const _CrownIdentity({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final onHeader = colors.onBrandHeader;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onHeader.withValues(alpha: 0.16),
            borderRadius: appRadius(AppRadii.md),
          ),
          child: Icon(Icons.storefront, size: 24, color: onHeader),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.titleMedium.copyWith(
                        color: onHeader,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(Icons.verified, size: 16, color: onHeader),
                ],
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.labelSmall.copyWith(
                  color: onHeader.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
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
          height: AppSpacing.xxxl * 5,
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

/// The DC 2×2 KPI grid of flat [DcStatCard]s — real counts, no fabricated deltas.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.counts, required this.l10n});

  final PublisherDashboardCounts counts;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    final cards = <Widget>[
      DcStatCard(
        icon: Icons.campaign,
        value: formatLocalizedNumber(counts.activeListings, locale),
        label: l10n.publisherDashboardStatActiveListings,
        onTap: () => context.push(AppRoutes.publisherMyListings),
      ),
      DcStatCard(
        icon: Icons.hourglass_empty,
        value: formatLocalizedNumber(counts.pendingListings, locale),
        label: l10n.publisherDashboardStatPendingListings,
        onTap: () => context.push(AppRoutes.publisherMyListings),
      ),
      DcStatCard(
        icon: Icons.mail_outline,
        value: formatLocalizedNumber(counts.newInquiries, locale),
        label: l10n.publisherDashboardStatNewInquiries,
        onTap: () => context.push(AppRoutes.inquiries),
      ),
      DcStatCard(
        icon: Icons.trending_up,
        value: formatLocalizedNumber(counts.leadEventsTotal, locale),
        label: l10n.publisherDashboardStatLeadEvents,
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
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, index) =>
          StaggeredListItem(index: index + 1, child: cards[index]),
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
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, index) => const LoadingState.card(),
    );
  }
}

/// The single-hue interactions bar chart, fed by the existing charts cubit's
/// gap-filled daily lead totals (last 7 days). Non-fatal: hides on load/error.
class _InteractionsChart extends StatelessWidget {
  const _InteractionsChart();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PublisherChartsCubit>(
      create: (_) => getIt<PublisherChartsCubit>()..load(),
      child: const _InteractionsChartView(),
    );
  }
}

class _InteractionsChartView extends StatelessWidget {
  const _InteractionsChartView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return BlocBuilder<PublisherChartsCubit, PublisherChartsState>(
      builder: (context, state) {
        if (state is! PublisherChartsLoaded) {
          return const SizedBox.shrink();
        }
        final series = state.leadsByDay;
        if (series.isEmpty) return const SizedBox.shrink();
        final last7 = series.length > 7
            ? series.sublist(series.length - 7)
            : series;
        final total = last7.fold<int>(0, (sum, p) => sum + p.total);

        return DcBarChart(
          title: l10n.publisherDashboardInteractionsTitle,
          rangeLabel: l10n.publisherDashboardChartRangeWeek,
          totalValue: formatLocalizedNumber(total, locale),
          totalLabel: l10n.publisherDashboardChartTotalLabel,
          bars: [
            for (final p in last7)
              DcBarChartBar(
                value: p.total,
                label: formatLocalizedNumber(p.day.day, locale),
              ),
          ],
        );
      },
    );
  }
}

class _ManageSectionLabel extends StatelessWidget {
  const _ManageSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Text(
      label,
      style: styles.labelLarge.copyWith(color: colors.onSurface),
    );
  }
}

/// The DC "إدارة النشاط" quick-link grid: 3-column tonal tiles routing to the
/// publisher's management surfaces.
class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.l10n, required this.state});

  final AppLocalizations l10n;
  final PublisherDashboardSummaryState state;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final newInquiries = state is PublisherDashboardSummaryLoaded
        ? (state as PublisherDashboardSummaryLoaded).counts.newInquiries
        : 0;

    final tiles = <Widget>[
      DcQuickLinkTile(
        icon: Icons.apartment,
        label: l10n.myListingsPageTitle,
        onTap: () => context.push(AppRoutes.publisherMyListings),
      ),
      DcQuickLinkTile(
        icon: Icons.forum_outlined,
        label: l10n.inquiry_inbox_app_bar_title,
        badgeLabel: newInquiries > 0
            ? formatLocalizedNumber(newInquiries, locale)
            : null,
        onTap: () => context.push(AppRoutes.inquiries),
      ),
      DcQuickLinkTile(
        icon: Icons.event_outlined,
        label: l10n.viewingsListTitle,
        onTap: () => _openViewings(context),
      ),
      DcQuickLinkTile(
        icon: Icons.groups_outlined,
        label: l10n.dashCrmTileTitle,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CrmPage()),
        ),
      ),
      DcQuickLinkTile(
        icon: Icons.bar_chart,
        label: l10n.leadAnalyticsTitle,
        onTap: () => _openLeadAnalytics(context),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) =>
          StaggeredListItem(index: index + 6, child: tiles[index]),
    );
  }

  void _openViewings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<ViewingsCubit>(
          create: (_) => getIt<ViewingsCubit>(),
          child: const ViewingsListPage(),
        ),
      ),
    );
  }

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
