// Phase 25 premium uplift v2 — publisher lead analytics.
//
// LeadAnalyticsPage: a pull-to-refresh surface for the authenticated publisher
// showing (1) a header total of lead events over the last 30 days, (2) a
// hand-built, gap-filled daily-leads BAR CHART (token-styled Containers — no
// chart package), and (3) a per-listing breakdown with small phone / WhatsApp /
// inquiry / favourite counters (StatCard idiom). Loading / empty / error are
// handled with the shared state widgets.
//
// Token-clean (AppColors/AppTextStyles/AppSpacing/appRadius + shared widgets),
// Arabic-first RTL-safe (directional padding/alignment, intl number/date
// formatting for the active locale). Pushed via Navigator.push by the dashboard
// — no go_router route.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/charts/token_bar_chart.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../domain/entities/publisher_lead_analytics.dart';
import '../bloc/publisher_analytics_cubit.dart';
import '../bloc/publisher_analytics_state.dart';

class LeadAnalyticsPage extends StatelessWidget {
  const LeadAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leadAnalyticsTitle)),
      body: BlocBuilder<PublisherAnalyticsCubit, PublisherAnalyticsState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () =>
                context.read<PublisherAnalyticsCubit>().refresh(),
            child: switch (state) {
              PublisherAnalyticsLoading() => const _AnalyticsSkeleton(),
              PublisherAnalyticsError(:final message) => _ErrorBody(
                message: message,
                l10n: l10n,
              ),
              PublisherAnalyticsLoaded(:final analytics) =>
                analytics.isEmpty
                    ? _EmptyBody(l10n: l10n)
                    : _AnalyticsBody(analytics: analytics, l10n: l10n),
            },
          );
        },
      ),
    );
  }
}

/// The loaded content: header total → bar chart → per-listing breakdown.
class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.analytics, required this.l10n});

  final PublisherLeadAnalytics analytics;
  final AppLocalizations l10n;

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
      children: [
        StaggeredListItem(
          index: 0,
          child: _TotalHeader(total: analytics.totalLeads, l10n: l10n),
        ),
        const SizedBox(height: AppSpacing.lg),
        StaggeredListItem(
          index: 1,
          child: _SectionLabel(label: l10n.leadAnalyticsTrendSectionLabel),
        ),
        const SizedBox(height: AppSpacing.md),
        StaggeredListItem(
          index: 2,
          child: _DailyBarChart(byDay: analytics.byDay, l10n: l10n),
        ),
        const SizedBox(height: AppSpacing.xl),
        StaggeredListItem(
          index: 3,
          child: _SectionLabel(label: l10n.leadAnalyticsByListingSectionLabel),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < analytics.byListing.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          StaggeredListItem(
            index: i + 4,
            child: _ListingBreakdownCard(
              listing: analytics.byListing[i],
              l10n: l10n,
            ),
          ),
        ],
      ],
    );
  }
}

/// The hero band: the grand total of lead events over the trailing window.
class _TotalHeader extends StatelessWidget {
  const _TotalHeader({required this.total, required this.l10n});

  final int total;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);

    return Container(
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
              LucideIcons.trending_up,
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
                  formatLocalizedNumber(total, locale),
                  style: styles.headlineLarge.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.leadAnalyticsTotalCaption,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A daily-leads bar chart for the trailing window. One bar per (gap-filled)
/// calendar day, height scaled to the busiest day, with a first→last date
/// caption. Phase 29: delegates to the shared [TokenBarChart] (identical
/// visuals — same card shell, normalization, min-nib, zero-stub, captions).
class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.byDay, required this.l10n});

  final List<PublisherDailyLeadTotal> byDay;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return TokenBarChart(
      values: byDay.map((p) => p.total).toList(growable: false),
      startCaption: byDay.isEmpty
          ? null
          : DateFormat.MMMd(locale).format(byDay.first.day),
      endCaption: byDay.isEmpty
          ? null
          : DateFormat.MMMd(locale).format(byDay.last.day),
    );
  }
}

/// A per-listing card: title + status chip, then a row of small lead counters
/// (phone / WhatsApp / inquiry / favourite) reusing the StatCard tinted-icon
/// idiom in a compact inline form.
class _ListingBreakdownCard extends StatelessWidget {
  const _ListingBreakdownCard({required this.listing, required this.l10n});

  final PublisherListingLeadAnalytics listing;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final locale = Localizations.localeOf(context);

    return Container(
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  listing.title.isEmpty
                      ? l10n.leadAnalyticsUntitledListing
                      : listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: styles.titleMedium.copyWith(color: colors.onSurface),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (listing.featured) ...[
                Icon(
                  LucideIcons.star,
                  size: AppSpacing.lg,
                  color: colors.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                l10n.leadAnalyticsListingTotal(
                  formatLocalizedNumber(listing.total, locale),
                ),
                style: styles.labelLarge.copyWith(color: colors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _LeadCounter(
                  icon: LucideIcons.phone,
                  value: formatLocalizedNumber(listing.phoneCount, locale),
                  label: l10n.leadAnalyticsSourcePhone,
                  accent: colors.primary,
                ),
              ),
              Expanded(
                child: _LeadCounter(
                  icon: LucideIcons.message_circle,
                  value: formatLocalizedNumber(listing.whatsappCount, locale),
                  label: l10n.leadAnalyticsSourceWhatsapp,
                  accent: colors.success,
                ),
              ),
              Expanded(
                child: _LeadCounter(
                  icon: LucideIcons.inbox,
                  value: formatLocalizedNumber(listing.inquiryCount, locale),
                  label: l10n.leadAnalyticsSourceInquiry,
                  accent: colors.accent,
                ),
              ),
              Expanded(
                child: _LeadCounter(
                  icon: LucideIcons.heart,
                  value: formatLocalizedNumber(listing.favoriteCount, locale),
                  label: l10n.leadAnalyticsSourceFavorite,
                  accent: colors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact lead counter: a tinted-circle glyph over a value + muted label.
/// The StatCard tinted-icon idiom, inlined for the four-up breakdown row.
class _LeadCounter extends StatelessWidget {
  const _LeadCounter({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: AppSpacing.lg, color: accent),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: styles.titleMedium.copyWith(color: colors.onSurface),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: styles.labelMedium.copyWith(color: colors.textMuted),
        ),
      ],
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

/// First-load skeleton: a header stub, a chart-area stub, then a few card stubs.
class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

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
        SizedBox(height: AppSpacing.md),
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
              title: l10n.leadAnalyticsError,
              message: message,
              onRetry: () =>
                  context.read<PublisherAnalyticsCubit>().refresh(),
            ),
          ),
        );
      },
    );
  }
}

/// Empty body — no listings or no leads yet. Scrollable for pull-to-refresh.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: EmptyState(
              icon: LucideIcons.chart_no_axes_column,
              headline: l10n.leadAnalyticsEmptyHeadline,
              body: l10n.leadAnalyticsEmptyBody,
            ),
          ),
        );
      },
    );
  }
}
