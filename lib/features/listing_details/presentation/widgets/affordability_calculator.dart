import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
// hide intl's TextDirection so it doesn't shadow dart:ui's.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';

/// Premium uplift — listing-detail financing ("حاسبة التمويل") calculator.
///
/// An expandable section that estimates a monthly payment from the listing's
/// primary price. Three sliders drive the estimate:
///  - down-payment %  (0–90)
///  - term in years   (1–25)
///  - profit/interest % (0–15)
///
/// The estimate is shown in the LISTING'S OWN currency — there is NO conversion
/// (the [currencyCode] suffix labels the primary price's currency verbatim).
/// All figures render in the active locale's numerals via [NumberFormat].
///
/// Self-contained + indicative only: it touches no BLoC, no network, no routing
/// — purely a local helper for the buyer.
class AffordabilityCalculator extends StatefulWidget {
  const AffordabilityCalculator({
    super.key,
    required this.price,
    required this.currencyCode,
  });

  /// The listing's primary price (its own currency — never converted).
  final Decimal price;

  /// The primary price's currency code (e.g. 'SYP', 'USD') — shown as a suffix
  /// beside the computed amounts.
  final String currencyCode;

  @override
  State<AffordabilityCalculator> createState() =>
      _AffordabilityCalculatorState();
}

class _AffordabilityCalculatorState extends State<AffordabilityCalculator> {
  static const double _downMin = 0;
  static const double _downMax = 90;
  static const double _termMin = 1;
  static const double _termMax = 25;
  static const double _rateMin = 0;
  static const double _rateMax = 15;

  bool _expanded = false;

  // Sensible defaults for a first glance.
  double _downPercent = 20;
  int _termYears = 10;
  double _ratePercent = 6;

  /// Amortized monthly payment in the listing's own currency.
  ///
  /// principal = price · (1 − down%); monthly rate r = (profit%/100)/12;
  /// n = years·12; payment = P·r / (1 − (1+r)^−n). When r == 0 the loan is
  /// straight-line: P / n.
  double get _monthlyPayment {
    final price = widget.price.toDouble();
    final principal = price * (1 - _downPercent / 100);
    if (principal <= 0) return 0;
    final n = _termYears * 12;
    final r = (_ratePercent / 100) / 12;
    if (r == 0) return principal / n;
    final factor = math.pow(1 + r, -n).toDouble();
    return principal * r / (1 - factor);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — taps to expand/collapse the calculator body.
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.calculator,
                      size: AppSpacing.xl,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.listing_details_affordability_title,
                        style: styles.titleMedium.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? LucideIcons.chevron_up
                          : LucideIcons.chevron_down,
                      size: AppSpacing.xl,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.base,
            curve: AppMotion.curve,
            alignment: AlignmentDirectional.topStart,
            child: _expanded
                ? _body(context, l10n, colors, styles)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    AppColors colors,
    AppTextStyles styles,
  ) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final intFmt = NumberFormat.decimalPattern(localeTag)
      ..maximumFractionDigits = 0;
    final percentFmt = NumberFormat.decimalPattern(localeTag)
      ..maximumFractionDigits = 0;

    String money(double value) => l10n.priceWithCurrency(
      intFmt.format(value.round()),
      widget.currencyCode,
    );
    String percent(double value) =>
        l10n.listing_details_affordability_percent_value(
          percentFmt.format(value.round()),
        );

    return Padding(
      // Top inset omitted (defaults to 0) — the header above already provides
      // the top padding; this keeps the body flush beneath it.
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prominent result — the estimated monthly payment leads.
          Container(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: appRadius(AppRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.listing_details_affordability_monthly_label,
                  style: styles.labelMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  money(_monthlyPayment),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: styles.priceLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _PercentSlider(
            label: l10n.listing_details_affordability_down_label,
            valueText: percent(_downPercent),
            min: _downMin,
            max: _downMax,
            divisions: (_downMax - _downMin).round(),
            value: _downPercent,
            onChanged: (v) => setState(() => _downPercent = v),
          ),
          _PercentSlider(
            label: l10n.listing_details_affordability_term_label,
            valueText: l10n.listing_details_affordability_years(
              intFmt.format(_termYears),
            ),
            min: _termMin,
            max: _termMax,
            divisions: (_termMax - _termMin).round(),
            value: _termYears.toDouble(),
            onChanged: (v) => setState(() => _termYears = v.round()),
          ),
          _PercentSlider(
            label: l10n.listing_details_affordability_rate_label,
            valueText: percent(_ratePercent),
            min: _rateMin,
            max: _rateMax,
            divisions: (_rateMax - _rateMin).round(),
            value: _ratePercent,
            onChanged: (v) => setState(() => _ratePercent = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.listing_details_affordability_disclaimer,
            style: styles.labelMedium.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A single-value slider with a header (label leading, current value trailing),
/// themed to the design tokens. Mirrors [RangeSliderField]'s SliderTheme idiom.
class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.label,
    required this.valueText,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double min;
  final double max;
  final int divisions;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: styles.labelLarge)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                valueText,
                style: styles.labelMedium.copyWith(color: colors.primary),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.outline,
              thumbColor: colors.primary,
              overlayColor: colors.primary.withAlpha(0x29),
              trackHeight: AppSpacing.xs,
            ),
            child: Slider(
              min: min,
              max: max,
              divisions: divisions,
              value: value.clamp(min, max),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
