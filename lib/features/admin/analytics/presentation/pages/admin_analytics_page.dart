// Phase 29 (029-crm-reels-growth) — W2: admin analytics page.
// Restyled DC "Blue Crown" Tier-E (035-redesign-ground-up): a crown over a
// white sheet holding a 2-col KPI row (real month-over-month trend), an
// evolution line chart, active-listings-by-governorate bars, and a daily lead
// trend. Reached only from the already-gated admin home (AdminHomePage). Each
// chart RPC re-gates server-side, so a partially-permissioned admin simply gets
// empty series and the corresponding card renders a muted empty hint (never an
// error). A transport failure shows a retry affordance. Token-clean + RTL.
//
// The evolution chart carries a NATIVE ⇄ fl_chart engine toggle: both renderers
// draw the identical series/styling under one shared shell, so the design can
// compare hand-built CustomPaint against the fl_chart package and pick. Pushed
// via Navigator.push — no go_router route.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../core/widgets/charts/dc_bar_chart.dart';
import '../../../../../core/widgets/charts/dc_line_chart.dart';
import '../../../../../core/widgets/charts/fl_line_chart.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../core/widgets/ds/dc_stat_card.dart';
import '../../../../../core/widgets/error_state.dart';
import '../../../../../core/widgets/loading_state.dart';
import '../../../../../core/widgets/locale_toggle_action.dart';
import '../../../../../core/widgets/staggered_list_item.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/util/localized_numbers.dart';
import '../../domain/entities/admin_analytics.dart';
import '../bloc/admin_analytics_cubit.dart';
import '../bloc/admin_analytics_state.dart';

class AdminAnalyticsPage extends StatelessWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcCrownScaffold(
      title: l10n.adminAnalyticsTitle,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      actions: const [LocaleToggleAction()],
      body: BlocBuilder<AdminAnalyticsCubit, AdminAnalyticsState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => context.read<AdminAnalyticsCubit>().refresh(),
            child: switch (state) {
              AdminAnalyticsLoading() => const _Skeleton(),
              AdminAnalyticsError(:final message) => _ErrorBody(
                message: message,
                l10n: l10n,
              ),
              AdminAnalyticsLoaded(:final analytics) => _Body(
                analytics: analytics,
                l10n: l10n,
              ),
            },
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.analytics, required this.l10n});

  final AdminAnalytics analytics;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final numLocale = Localizations.localeOf(context);
    final locale = numLocale.toLanguageTag();
    final isArabic = numLocale.languageCode == 'ar';

    // Active-listings-by-governorate → top few vertical bars (labels stay legible).
    final govs = analytics.listingsByGovernorate;
    final topGovs = govs.length > 6 ? govs.sublist(0, 6) : govs;

    final sections = <Widget>[
      // KPI row — real values, month-over-month trend where the series supports it.
      _KpiGrid(analytics: analytics, l10n: l10n, numLocale: numLocale),
      // Evolution over time (listings ⇄ users), native ⇄ fl_chart engine toggle.
      _EvolutionCard(
        listings: analytics.listingsByMonth,
        users: analytics.profilesByMonth,
        locale: locale,
        l10n: l10n,
      ),
      // Active listings by governorate.
      if (topGovs.isEmpty)
        _EmptyChartCard(
          title: l10n.adminAnalyticsListingsByGovernorateTitle,
          hint: l10n.adminAnalyticsEmptyHint,
        )
      else
        DcBarChart(
          title: l10n.adminAnalyticsListingsByGovernorateTitle,
          bars: [
            for (final g in topGovs)
              DcBarChartBar(
                value: g.total,
                label: isArabic
                    ? (g.nameAr.isEmpty ? g.nameEn : g.nameAr)
                    : (g.nameEn.isEmpty ? g.nameAr : g.nameEn),
              ),
          ],
        ),
      // Daily lead events — a dense trend line (range in the header, no per-day axis).
      if (analytics.leadEventsByDay.isEmpty)
        _EmptyChartCard(
          title: l10n.adminAnalyticsLeadEventsByDayTitle,
          hint: l10n.adminAnalyticsEmptyHint,
        )
      else
        DcLineChart(
          title: l10n.adminAnalyticsLeadEventsByDayTitle,
          values: analytics.leadEventsByDay
              .map((p) => p.total)
              .toList(growable: false),
          labels: const [],
          rangeLabel:
              '${DateFormat.MMMd(locale).format(analytics.leadEventsByDay.first.day)}'
              ' – '
              '${DateFormat.MMMd(locale).format(analytics.leadEventsByDay.last.day)}',
          totalValue: formatLocalizedNumber(
            analytics.leadEventsByDay.fold<int>(0, (s, p) => s + p.total),
            numLocale,
          ),
        ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          StaggeredListItem(index: i, child: sections[i]),
        ],
      ],
    );
  }
}

// ─── KPI row ──────────────────────────────────────────────────────────────────

/// A 2×2 grid of flat [DcStatCard] KPIs derived from the real series. Month
/// cards carry an honest month-over-month delta pill; the window totals do not
/// (a single window has nothing to compare against — never fabricate a trend).
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.analytics,
    required this.l10n,
    required this.numLocale,
  });

  final AdminAnalytics analytics;
  final AppLocalizations l10n;
  final Locale numLocale;

  /// Month-over-month delta of the last two points, as a signed-free "N%" string
  /// plus an "up?" flag (the pill draws the arrow). Null when there's no prior
  /// month or the prior month was zero (an undefined / infinite percentage).
  (String?, bool) _mom(List<AdminMonthlyTotal> pts) {
    if (pts.length < 2) return (null, true);
    final last = pts.last.total;
    final prev = pts[pts.length - 2].total;
    if (prev == 0) return (null, true);
    final pct = ((last - prev) / prev * 100).round();
    return ('${pct.abs()}%', pct >= 0);
  }

  @override
  Widget build(BuildContext context) {
    String fmt(int v) => formatLocalizedNumber(v, numLocale);

    final listingsMonth = analytics.listingsByMonth.isEmpty
        ? 0
        : analytics.listingsByMonth.last.total;
    final (lDelta, lUp) = _mom(analytics.listingsByMonth);
    final usersMonth = analytics.profilesByMonth.isEmpty
        ? 0
        : analytics.profilesByMonth.last.total;
    final (uDelta, uUp) = _mom(analytics.profilesByMonth);
    final leads = analytics.leadEventsByDay.fold<int>(0, (s, p) => s + p.total);
    final active = analytics.listingsByGovernorate.fold<int>(
      0,
      (s, p) => s + p.total,
    );

    final cards = <Widget>[
      DcStatCard(
        icon: LucideIcons.building_2,
        value: fmt(listingsMonth),
        label: l10n.adminAnalyticsKpiListingsMonth,
        delta: lDelta,
        trendUp: lUp,
      ),
      DcStatCard(
        icon: LucideIcons.users,
        value: fmt(usersMonth),
        label: l10n.adminAnalyticsKpiNewUsers,
        delta: uDelta,
        trendUp: uUp,
      ),
      DcStatCard(
        icon: LucideIcons.inbox,
        value: fmt(leads),
        label: l10n.adminAnalyticsKpiLeads30d,
      ),
      DcStatCard(
        icon: LucideIcons.circle_check_big,
        value: fmt(active),
        label: l10n.adminAnalyticsKpiActiveListings,
      ),
    ];

    Widget row(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: a),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: b),
      ],
    );

    return Column(
      children: [
        row(cards[0], cards[1]),
        const SizedBox(height: AppSpacing.md),
        row(cards[2], cards[3]),
      ],
    );
  }
}

// ─── Evolution card (series + engine toggles) ─────────────────────────────────

class _EvolutionCard extends StatefulWidget {
  const _EvolutionCard({
    required this.listings,
    required this.users,
    required this.locale,
    required this.l10n,
  });

  final List<AdminMonthlyTotal> listings;
  final List<AdminMonthlyTotal> users;
  final String locale;
  final AppLocalizations l10n;

  @override
  State<_EvolutionCard> createState() => _EvolutionCardState();
}

class _EvolutionCardState extends State<_EvolutionCard> {
  int _series = 0; // 0 = listings, 1 = users
  bool _native = true; // true = DcLineChartPlot, false = FlLineChartPlot

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = widget.l10n;
    final numLocale = Localizations.localeOf(context);

    final source = _series == 0 ? widget.listings : widget.users;
    // Show the most recent 6 months so the month axis stays readable.
    final pts = source.length > 6
        ? source.sublist(source.length - 6)
        : source;

    if (pts.isEmpty) {
      return _EmptyChartCard(
        title: l10n.adminAnalyticsEvolutionTitle,
        hint: l10n.adminAnalyticsEmptyHint,
      );
    }

    final values = pts.map((p) => p.total).toList(growable: false);
    final labels = pts
        .map((p) => DateFormat.MMM(widget.locale).format(p.month))
        .toList(growable: false);
    final total = pts.fold<int>(0, (s, p) => s + p.total);
    final seriesLabel = _series == 0
        ? l10n.adminAnalyticsSeriesListings
        : l10n.adminAnalyticsSeriesUsers;

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + running total for the selected series.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.adminAnalyticsEvolutionTitle,
                  style: styles.labelLarge.copyWith(color: colors.onSurface),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatLocalizedNumber(total, numLocale),
                    style: styles.titleLarge.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    seriesLabel,
                    style: styles.labelSmall.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Series toggle: listings ⇄ users.
          _SegToggle(
            labels: [
              l10n.adminAnalyticsSeriesListings,
              l10n.adminAnalyticsSeriesUsers,
            ],
            index: _series,
            onChanged: (i) => setState(() => _series = i),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The plot — swapped by engine, identical data + styling either way.
          if (_native)
            DcLineChartPlot(values: values)
          else
            FlLineChartPlot(values: values),
          // Shared month axis (rendered by the shell, not the plot).
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: styles.labelSmall.copyWith(color: colors.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Engine comparison toggle (the founder's chart-package experiment).
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.adminAnalyticsEngineLabel,
                  style: styles.labelSmall.copyWith(color: colors.textMuted),
                ),
              ),
              _SegToggle(
                labels: [
                  l10n.adminAnalyticsEngineNative,
                  l10n.adminAnalyticsEngineFlChart,
                ],
                index: _native ? 0 : 1,
                onChanged: (i) => setState(() => _native = i == 0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact 2-way segmented toggle on a [colors.surfaceVariant] track; the
/// selected segment lifts onto a [colors.card] pill. Token-clean.
class _SegToggle extends StatelessWidget {
  const _SegToggle({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: i == index
                    ? BoxDecoration(
                        color: colors.card,
                        borderRadius: appRadius(AppRadii.pill),
                      )
                    : null,
                child: Text(
                  labels[i],
                  style: styles.labelMedium.copyWith(
                    color: i == index ? colors.onSurface : colors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty chart card ─────────────────────────────────────────────────────────

/// A flat titled card carrying only a muted "no data" hint — shown when a
/// series is empty (no data, or the caller lacks that section's permission).
class _EmptyChartCard extends StatelessWidget {
  const _EmptyChartCard({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: styles.labelLarge.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.xl,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.chart_no_axes_column,
                    size: AppSpacing.xxl,
                    color: colors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading / error states ───────────────────────────────────────────────────

/// First-load skeleton: a few card stubs.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: const [
        LoadingState.card(),
        SizedBox(height: AppSpacing.lg),
        LoadingState.card(),
        SizedBox(height: AppSpacing.lg),
        LoadingState.card(),
        SizedBox(height: AppSpacing.lg),
        LoadingState.card(),
      ],
    );
  }
}

/// Error body — scrollable so pull-to-refresh still works.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.l10n});

  final String message;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: ErrorState(
              title: l10n.adminAnalyticsError,
              message: message,
              onRetry: () => context.read<AdminAnalyticsCubit>().refresh(),
            ),
          ),
        );
      },
    );
  }
}
