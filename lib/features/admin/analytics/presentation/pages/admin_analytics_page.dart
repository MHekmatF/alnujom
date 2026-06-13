// Phase 29 (029-crm-reels-growth) — W2: admin analytics page.
//
// A pull-to-refresh surface with four charts, each in its own titled card:
//   • listings created per month (bar)
//   • new users per month (bar)
//   • lead events per day (bar)
//   • active listings by governorate (horizontal bars, top 10)
//
// Reached only from the already-gated admin home (AdminHomePage). Each chart RPC
// re-gates server-side, so a partially-permissioned admin simply gets empty
// series and the corresponding card renders a muted empty hint (never an error).
// A transport failure shows a retry affordance. Token-clean + Arabic-first RTL.
// Pushed via Navigator.push — no go_router route.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/widgets/charts/token_bar_chart.dart';
import '../../../../../core/widgets/charts/token_hbar_list.dart';
import '../../../../../core/widgets/error_state.dart';
import '../../../../../core/widgets/loading_state.dart';
import '../../../../../core/widgets/staggered_list_item.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/admin_analytics.dart';
import '../bloc/admin_analytics_cubit.dart';
import '../bloc/admin_analytics_state.dart';
import '../widgets/admin_chart_card.dart';

class AdminAnalyticsPage extends StatelessWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminAnalyticsTitle)),
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final sections = <Widget>[
      // Listings created per month.
      _MonthlyBarCard(
        title: l10n.adminAnalyticsListingsByMonthTitle,
        emptyHint: l10n.adminAnalyticsEmptyHint,
        points: analytics.listingsByMonth,
        locale: locale,
      ),
      // New users per month.
      _MonthlyBarCard(
        title: l10n.adminAnalyticsUsersByMonthTitle,
        emptyHint: l10n.adminAnalyticsEmptyHint,
        points: analytics.profilesByMonth,
        locale: locale,
      ),
      // Lead events per day.
      _DailyBarCard(
        title: l10n.adminAnalyticsLeadEventsByDayTitle,
        emptyHint: l10n.adminAnalyticsEmptyHint,
        points: analytics.leadEventsByDay,
        locale: locale,
      ),
      // Active listings by governorate.
      _GovernorateHbarCard(
        title: l10n.adminAnalyticsListingsByGovernorateTitle,
        emptyHint: l10n.adminAnalyticsEmptyHint,
        points: analytics.listingsByGovernorate,
        locale: locale,
        isArabic: isArabic,
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

/// A monthly bar chart in a titled card (or an empty hint when no data).
class _MonthlyBarCard extends StatelessWidget {
  const _MonthlyBarCard({
    required this.title,
    required this.emptyHint,
    required this.points,
    required this.locale,
  });

  final String title;
  final String emptyHint;
  final List<AdminMonthlyTotal> points;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return AdminChartCard(
      title: title,
      isEmpty: points.isEmpty,
      emptyHint: emptyHint,
      child: TokenBarChart(
        values: points.map((p) => p.total).toList(growable: false),
        startCaption: points.isEmpty
            ? null
            : DateFormat.yMMM(locale).format(points.first.month),
        endCaption: points.isEmpty
            ? null
            : DateFormat.yMMM(locale).format(points.last.month),
      ),
    );
  }
}

/// A daily bar chart in a titled card (or an empty hint when no data).
class _DailyBarCard extends StatelessWidget {
  const _DailyBarCard({
    required this.title,
    required this.emptyHint,
    required this.points,
    required this.locale,
  });

  final String title;
  final String emptyHint;
  final List<AdminDailyTotal> points;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return AdminChartCard(
      title: title,
      isEmpty: points.isEmpty,
      emptyHint: emptyHint,
      child: TokenBarChart(
        values: points.map((p) => p.total).toList(growable: false),
        startCaption: points.isEmpty
            ? null
            : DateFormat.MMMd(locale).format(points.first.day),
        endCaption: points.isEmpty
            ? null
            : DateFormat.MMMd(locale).format(points.last.day),
      ),
    );
  }
}

/// A horizontal-bar list of active listings per governorate (top 10).
class _GovernorateHbarCard extends StatelessWidget {
  const _GovernorateHbarCard({
    required this.title,
    required this.emptyHint,
    required this.points,
    required this.locale,
    required this.isArabic,
  });

  final String title;
  final String emptyHint;
  final List<AdminGovernorateTotal> points;
  final String locale;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fmt = NumberFormat.decimalPattern(locale);

    return AdminChartCard(
      title: title,
      isEmpty: points.isEmpty,
      emptyHint: emptyHint,
      child: TokenHbarList(
        items: points.map((p) {
          final name = isArabic
              ? (p.nameAr.isEmpty ? p.nameEn : p.nameAr)
              : (p.nameEn.isEmpty ? p.nameAr : p.nameEn);
          return TokenHbarItem(
            label: name,
            value: p.total,
            valueLabel: fmt.format(p.total),
            barColor: colors.accent,
          );
        }).toList(growable: false),
      ),
    );
  }
}

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
