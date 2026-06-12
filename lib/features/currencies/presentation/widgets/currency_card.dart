import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/currency_with_latest_rates.dart';
import 'latest_rate_subline.dart';
import 'system_currency_badge.dart';

enum _CurrencyCardAction { edit, history, delete }

class CurrencyCard extends StatelessWidget {
  const CurrencyCard({
    required this.summary,
    required this.locale,
    required this.onEdit,
    required this.onViewHistory,
    this.onDelete,
    super.key,
  });

  final CurrencyWithLatestRates summary;
  final Locale locale;
  final VoidCallback onEdit;
  final VoidCallback onViewHistory;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final currency = summary.currency;
    final latestRates = summary.latestRates.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        onTap: onViewHistory,
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
                color: colors.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                LucideIcons.coins,
                color: colors.primary,
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
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.currencyOptionLabel(
                          currency.code,
                          currency.localizedName(locale),
                        ),
                        style: styles.bodyLarge,
                      ),
                      Text(
                        currency.symbol,
                        style: styles.bodyMedium.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      if (currency.isSystem) const SystemCurrencyBadge(),
                      if (!currency.isActive) _HiddenPill(l10n.hiddenBadge),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (latestRates.isEmpty)
                    Text(
                      l10n.rateNotSetHint,
                      style: styles.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in latestRates)
                          LatestRateSubline(
                            baseCurrency: currency.code,
                            targetCurrencyCode: entry.key,
                            latestRate: entry.value,
                            locale: locale,
                          ),
                      ],
                    ),
                ],
              ),
            ),
            PopupMenuButton<_CurrencyCardAction>(
              icon: Icon(
                LucideIcons.ellipsis_vertical,
                color: colors.textMuted,
              ),
              onSelected: (action) => switch (action) {
                _CurrencyCardAction.edit => onEdit(),
                _CurrencyCardAction.history => onViewHistory(),
                _CurrencyCardAction.delete => onDelete?.call(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _CurrencyCardAction.edit,
                  child: Text(l10n.editAffordance),
                ),
                PopupMenuItem(
                  value: _CurrencyCardAction.history,
                  child: Text(l10n.viewHistoryButton),
                ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: _CurrencyCardAction.delete,
                    child: Text(l10n.deleteButton),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft "hidden" pill (replaces the stock Material [Chip]).
class _HiddenPill extends StatelessWidget {
  const _HiddenPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: colors.outline),
      ),
      child: Text(
        label,
        style: styles.labelMedium.copyWith(color: colors.textMuted),
      ),
    );
  }
}
