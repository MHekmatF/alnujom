import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/deed_finish_labels.dart';

/// Phase 035 Stage 3 — the listing-detail verification + Syria-attributes
/// section: a green "موثّق ميدانياً" trust block when field-verified, plus
/// deed (الطابو) and finish (الكسوة) tiles. Renders nothing when none of the
/// data is present, so it never leaves an empty gap.
class ListingVerificationSection extends StatelessWidget {
  const ListingVerificationSection({
    required this.isVerified,
    this.deedType,
    this.finishLevel,
    super.key,
  });

  final bool isVerified;
  final String? deedType;
  final String? finishLevel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDeed = deedType != null;
    final hasFinish = finishLevel != null;
    if (!isVerified && !hasDeed && !hasFinish) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isVerified) ...[
          _TrustBlock(),
          const SizedBox(height: AppSpacing.md),
        ],
        if (hasDeed || hasFinish)
          Row(
            children: [
              if (hasDeed)
                Expanded(
                  child: _AttrTile(
                    icon: LucideIcons.scroll_text,
                    label: l10n.detail_deed_label,
                    value: deedTypeLabel(l10n, deedType),
                  ),
                ),
              if (hasDeed && hasFinish) const SizedBox(width: AppSpacing.sm),
              if (hasFinish)
                Expanded(
                  child: _AttrTile(
                    icon: LucideIcons.paintbrush,
                    label: l10n.detail_finish_label,
                    value: finishLevelLabel(l10n, finishLevel),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _TrustBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.verifiedContainer,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.verified),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.badge_check,
            color: colors.verified,
            size: AppSpacing.xxl,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.detail_field_verified_title,
                  style: styles.titleMedium.copyWith(color: colors.verified),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.detail_field_verified_body,
                  style: styles.bodyMedium.copyWith(color: colors.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttrTile extends StatelessWidget {
  const _AttrTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSpacing.xl, color: colors.primary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: styles.labelMedium.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: styles.labelLarge),
        ],
      ),
    );
  }
}
