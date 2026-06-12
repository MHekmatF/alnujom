import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/rate_formatter.dart';
import '../../../../shared/util/arabic_digits.dart';
import '../../domain/entities/exchange_rate.dart';
import 'derived_badge.dart';

class ExchangeRateRow extends StatelessWidget {
  const ExchangeRateRow({required this.exchangeRate, super.key});

  final ExchangeRate exchangeRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final dateFormat = intl.DateFormat.yMMMd(locale.toLanguageTag()).add_Hm();
    final source = exchangeRate.source?.trim().isEmpty == false
        ? exchangeRate.source!
        : l10n.unknownActorLabel;
    final displayName = exchangeRate.setByDisplayName?.trim();
    final setBy = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (exchangeRate.setBy == null
              ? l10n.systemActorLabel
              : l10n.unknownActorLabel);

    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return AppSurface(
      radius: AppRadii.lg,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.xxl + AppSpacing.lg,
            height: AppSpacing.xxl + AppSpacing.lg,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent.withValues(alpha: 0.12),
            ),
            child: Icon(
              LucideIcons.arrow_right_left,
              color: colors.accent,
              size: AppSpacing.xl,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.exchangeRatePairLabel(
                        exchangeRate.baseCurrency,
                        exchangeRate.targetCurrency,
                      ),
                      style: styles.bodyLarge,
                    ),
                    if (exchangeRate.isDerived) const DerivedBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  RateFormatter.format(exchangeRate.rate, locale),
                  style: styles.labelLarge.copyWith(color: colors.primary),
                ),
                Text(
                  _localizeDate(
                    locale,
                    dateFormat,
                    exchangeRate.effectiveAt,
                    l10n,
                  ),
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
                Text(
                  l10n.setByLineFormat(setBy),
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
                Text(
                  l10n.sourceLineFormat(source),
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _localizeDate(
    Locale locale,
    intl.DateFormat dateFormat,
    DateTime ts,
    AppLocalizations l10n,
  ) {
    final raw = dateFormat.format(ts.toLocal());
    final localized = locale.languageCode == 'ar'
        ? toArabicIndicNumerals(raw)
        : raw;
    return '${l10n.effectiveAtLabel}: $localized';
  }
}
