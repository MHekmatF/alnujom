// Phase 29 (029-crm-reels-growth) — W2: publisher dashboard charts section.
//
// An additive analytics band on the publisher dashboard, rendered below the KPI
// grid. Four titled cards:
//   • leads per day (bar)            — publisher_lead_totals_by_day
//   • inquiries per day (bar)        — publisher_inquiries_by_day (new)
//   • viewings by status (h-bars)    — publisher_viewings_by_status (new)
//   • listings by status (h-bars)    — derived from publisher_dashboard_counts
//
// The three RPC-backed series come from a self-provided PublisherChartsCubit;
// the listings-by-status series is derived from the [counts] passed in by the
// dashboard. Token-clean + Arabic-first RTL; values use NumberFormat in the
// active locale (Arabic-Indic digits under `ar`).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/charts/token_bar_chart.dart';
import '../../../../core/widgets/charts/token_hbar_list.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/publisher_dashboard_counts.dart';
import '../bloc/publisher_charts_cubit.dart';
import '../bloc/publisher_charts_state.dart';

class PublisherChartsSection extends StatelessWidget {
  const PublisherChartsSection({required this.counts, super.key});

  /// The dashboard KPI counts — used to derive the listings-by-status bars.
  final PublisherDashboardCounts counts;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PublisherChartsCubit>(
      create: (_) => getIt<PublisherChartsCubit>()..load(),
      child: _ChartsView(counts: counts),
    );
  }
}

class _ChartsView extends StatelessWidget {
  const _ChartsView({required this.counts});

  final PublisherDashboardCounts counts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final colors = AppColors.of(context);
    final fmt = NumberFormat.decimalPattern(locale);

    return BlocBuilder<PublisherChartsCubit, PublisherChartsState>(
      builder: (context, state) {
        // The listings-by-status h-bar list is always available (derived from
        // counts), independent of the RPC-backed series' state.
        final listingsByStatus = _ChartCard(
          title: l10n.publisherChartsListingsByStatusTitle,
          isEmpty: counts.totalListings == 0,
          emptyHint: l10n.publisherChartsEmptyHint,
          child: TokenHbarList(
            items: [
              TokenHbarItem(
                label: l10n.publisherChartsStatusActive,
                value: counts.activeListings,
                valueLabel: fmt.format(counts.activeListings),
                barColor: colors.success,
              ),
              TokenHbarItem(
                label: l10n.publisherChartsStatusPending,
                value: counts.pendingListings,
                valueLabel: fmt.format(counts.pendingListings),
                barColor: colors.warning,
              ),
              TokenHbarItem(
                label: l10n.publisherChartsStatusRejected,
                value: counts.rejectedListings,
                valueLabel: fmt.format(counts.rejectedListings),
                barColor: colors.error,
              ),
            ],
          ),
        );

        final cards = <Widget>[];

        switch (state) {
          case PublisherChartsLoading():
            cards.addAll(const [
              LoadingState.card(),
              SizedBox(height: AppSpacing.md),
              LoadingState.card(),
            ]);
          case PublisherChartsError():
            // A failure of the RPC-backed series is non-fatal to the dashboard:
            // we simply drop those three cards and still show listings-by-status.
            break;
          case PublisherChartsLoaded(
            :final leadsByDay,
            :final inquiriesByDay,
            :final viewingsByStatus,
          ):
            cards.addAll([
              _ChartCard(
                title: l10n.publisherChartsLeadsByDayTitle,
                isEmpty: leadsByDay.every((p) => p.total == 0),
                emptyHint: l10n.publisherChartsEmptyHint,
                child: TokenBarChart(
                  values:
                      leadsByDay.map((p) => p.total).toList(growable: false),
                  startCaption: leadsByDay.isEmpty
                      ? null
                      : DateFormat.MMMd(locale).format(leadsByDay.first.day),
                  endCaption: leadsByDay.isEmpty
                      ? null
                      : DateFormat.MMMd(locale).format(leadsByDay.last.day),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartCard(
                title: l10n.publisherChartsInquiriesByDayTitle,
                isEmpty: inquiriesByDay.every((p) => p.total == 0),
                emptyHint: l10n.publisherChartsEmptyHint,
                child: TokenBarChart(
                  barColor: colors.accent,
                  values: inquiriesByDay
                      .map((p) => p.total)
                      .toList(growable: false),
                  startCaption: inquiriesByDay.isEmpty
                      ? null
                      : DateFormat.MMMd(
                          locale,
                        ).format(inquiriesByDay.first.day),
                  endCaption: inquiriesByDay.isEmpty
                      ? null
                      : DateFormat.MMMd(locale).format(inquiriesByDay.last.day),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartCard(
                title: l10n.publisherChartsViewingsByStatusTitle,
                isEmpty: viewingsByStatus.isEmpty,
                emptyHint: l10n.publisherChartsEmptyHint,
                child: TokenHbarList(
                  items: viewingsByStatus
                      .map(
                        (s) => TokenHbarItem(
                          label: _viewingStatusLabel(s.status, l10n),
                          value: s.total,
                          valueLabel: fmt.format(s.total),
                          barColor: _viewingStatusColor(s.status, colors),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ]);
        }

        return Column(
          children: [
            ...cards,
            if (cards.isNotEmpty) const SizedBox(height: AppSpacing.md),
            listingsByStatus,
          ],
        );
      },
    );
  }

  String _viewingStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'requested':
        return l10n.publisherChartsViewingRequested;
      case 'confirmed':
        return l10n.publisherChartsViewingConfirmed;
      case 'declined':
        return l10n.publisherChartsViewingDeclined;
      case 'cancelled':
        return l10n.publisherChartsViewingCancelled;
      default:
        return status;
    }
  }

  Color _viewingStatusColor(String status, AppColors colors) {
    switch (status) {
      case 'confirmed':
        return colors.success;
      case 'declined':
        return colors.error;
      case 'cancelled':
        return colors.textMuted;
      case 'requested':
      default:
        return colors.warning;
    }
  }
}

/// A titled card with an empty-hint fallback — local mirror of the admin chart
/// card shell, scoped to the dashboard section.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    required this.isEmpty,
    required this.emptyHint,
  });

  final String title;
  final Widget child;
  final bool isEmpty;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: styles.titleMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.lg,
              ),
              child: Text(
                emptyHint,
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
              ),
            )
          else
            child,
        ],
      ),
    );
  }
}
