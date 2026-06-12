import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../l10n/app_localizations.dart';

/// Phase 25 — feature-duration chooser for the admin listing-review preview.
///
/// Offers 7 / 14 / 30 day options. When the listing is already featured
/// (`isCurrentlyFeatured`), a destructive "remove featuring" option is also
/// shown. Returns the selected duration in days via `Navigator.pop`:
///   - 7 / 14 / 30 → feature for that many days
///   - 0           → remove featuring
///   - null        → cancelled / dismissed
///
/// Kept as a hand-rolled [AlertDialog]: this is a chooser whose options pop
/// the result directly (no primary action), which [AppDialog]'s fixed
/// confirm/cancel pair cannot express.
class FeatureListingDialog extends StatelessWidget {
  const FeatureListingDialog({super.key, required this.isCurrentlyFeatured});

  /// Whether the listing currently has an active `featured_until`.
  final bool isCurrentlyFeatured;

  /// Opens the chooser. Returns the number of days (0 = remove) or null.
  static Future<int?> show(
    BuildContext context, {
    required bool isCurrentlyFeatured,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) =>
          FeatureListingDialog(isCurrentlyFeatured: isCurrentlyFeatured),
    );
  }

  static const List<int> _durations = [7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return AlertDialog(
      icon: Container(
        width: AppSpacing.xxxl,
        height: AppSpacing.xxxl,
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.star,
          color: colors.warning,
          size: AppSpacing.xl,
        ),
      ),
      title: Text(l10n.adminFeatureDialogTitle, style: styles.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.adminFeatureDialogBody,
            style: styles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final days in _durations) ...[
            _DurationTile(
              label: l10n.adminFeatureDialogOptionDays(days),
              icon: LucideIcons.star,
              foreground: colors.primary,
              onTap: () => Navigator.of(context).pop(days),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (isCurrentlyFeatured) ...[
            const SizedBox(height: AppSpacing.xs),
            _DurationTile(
              label: l10n.adminFeatureDialogRemove,
              icon: LucideIcons.star_off,
              foreground: colors.error,
              onTap: () => Navigator.of(context).pop(0),
            ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: l10n.adminFeatureDialogCancel,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

/// Branded chooser row — tinted-circle leading glyph + label on a hairline
/// surface (replaces the stock [ListTile]).
class _DurationTile extends StatelessWidget {
  const _DurationTile({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return AppSurface(
      radius: AppRadii.md,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.xxl + AppSpacing.sm,
            height: AppSpacing.xxl + AppSpacing.sm,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: foreground.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: foreground, size: AppSpacing.lg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: styles.bodyLarge.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
