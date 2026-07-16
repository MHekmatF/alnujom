import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
// hide intl's TextDirection so it doesn't shadow dart:ui's.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../domain/entities/market_trend_point.dart';
import '../bloc/market_insights_cubit.dart';

/// Spec 028 — the "Market insights" section on the listing details page: a
/// section header (tinted icon circle + title) over a hand-built monthly
/// average-asking-price BAR CHART for the listing's governorate + property
/// type (and its own city / purpose), in the listing's primary currency.
///
/// Chart idiom cloned from the publisher lead-analytics `_DailyBarChart`
/// (token-styled Containers, tallest-bar normalization — no chart package).
/// Month labels + figures render via intl in the active locale (Arabic-Indic
/// digits for free under `ar`).
///
/// Self-contained: hosts its own [MarketInsightsCubit] and fires the fetch
/// once. Collapses to nothing when the listing has no governorate / primary
/// currency, when the RPC fails, or when the area has fewer than 3 monthly
/// points in the listing's primary currency — it never blocks the page.
class MarketInsightsSection extends StatelessWidget {
  const MarketInsightsSection({
    super.key,
    required this.governorateId,
    required this.propertyType,
    required this.currencyCode,
    this.cityId,
    this.purpose,
  });

  /// The listing's governorate id (null → section collapses).
  final String? governorateId;

  /// The listing's property type as the DB enum string (e.g. 'apartment').
  final String propertyType;

  /// The listing's primary-price currency code (null → section collapses).
  final String? currencyCode;

  /// The listing's city id (optional narrowing).
  final String? cityId;

  /// The listing's purpose as the DB enum string (optional narrowing).
  final String? purpose;

  @override
  Widget build(BuildContext context) {
    final governorateId = this.governorateId;
    final currencyCode = this.currencyCode;
    if (governorateId == null || currencyCode == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider<MarketInsightsCubit>(
      create: (_) => getIt<MarketInsightsCubit>()
        ..load(
          governorateId: governorateId,
          propertyType: propertyType,
          currencyCode: currencyCode,
          cityId: cityId,
          purpose: purpose,
        ),
      child: _MarketInsightsBody(currencyCode: currencyCode),
    );
  }
}

class _MarketInsightsBody extends StatelessWidget {
  const _MarketInsightsBody({required this.currencyCode});

  final String currencyCode;

  /// Plot height for the tallest bar (mirrors the lead-analytics chart).
  static const double _chartHeight = 120;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MarketInsightsCubit, MarketInsightsState>(
      builder: (context, state) {
        // Initial / loading / error / thin-sample all collapse silently —
        // the section appears only once a meaningful trend is ready.
        if (state.status != MarketInsightsStatus.loaded ||
            state.points.isEmpty) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);
        final elevation = AppElevation.of(context);
        final locale = Localizations.localeOf(context);
        final localeTag = locale.toLanguageTag();

        final points = state.points;
        final maxAvg = points.fold<double>(
          0,
          (peak, p) =>
              p.avgPrice.toDouble() > peak ? p.avgPrice.toDouble() : peak,
        );
        // Listing-count-weighted overall average for the caption.
        final totalCount = points.fold<int>(
          0,
          (sum, p) => sum + p.listingCount,
        );
        final weightedSum = points.fold<double>(
          0,
          (sum, p) => sum + p.avgPrice.toDouble() * p.listingCount,
        );
        final overallAvg = totalCount == 0 ? 0.0 : weightedSum / totalCount;
        final avgPriceText = l10n.priceWithCurrency(
          formatLocalizedNumber(overallAvg.round(), locale),
          currencyCode,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header — tinted icon circle + title.
            Row(
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    LucideIcons.chart_column,
                    size: AppSpacing.lg,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.marketInsightsTitle,
                    style: styles.titleMedium.copyWith(color: colors.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Chart card — token-styled bars, tallest-bar normalization.
            Container(
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final point in points)
                        Expanded(
                          child: _MonthBar(
                            point: point,
                            fraction: maxAvg == 0
                                ? 0
                                : point.avgPrice.toDouble() / maxAvg,
                            maxHeight: _chartHeight,
                            localeTag: localeTag,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.marketInsightsAvgCaption(avgPriceText),
                    style: styles.labelLarge.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.marketInsightsBasedOn(totalCount),
                    style: styles.labelMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
    );
  }
}

/// One monthly bar with its month label beneath. Height scales against the
/// busiest month; a minimum nib keeps thin months visible. RTL-safe (the
/// parent Row lays out start→end, so it reverses naturally under RTL).
class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.point,
    required this.fraction,
    required this.maxHeight,
    required this.localeTag,
  });

  final MarketTrendPoint point;
  final double fraction;
  final double maxHeight;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final double height = (maxHeight * fraction).clamp(
      AppSpacing.xs,
      maxHeight,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.xxs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: appRadius(AppRadii.sm),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormat.MMM(localeTag).format(point.month),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: styles.labelMedium.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
