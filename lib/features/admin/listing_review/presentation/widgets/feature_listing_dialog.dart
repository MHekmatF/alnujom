import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../l10n/app_localizations.dart';

/// Phase 25 — feature-duration chooser for the admin listing-review preview.
///
/// Offers 7 / 14 / 30 day options. When the listing is already featured
/// (`isCurrentlyFeatured`), a destructive "remove featuring" option is also
/// shown. Returns the selected duration in days via `Navigator.pop`:
///   - 7 / 14 / 30 → feature for that many days
///   - 0           → remove featuring
///   - null        → cancelled / dismissed
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
      title: Text(l10n.adminFeatureDialogTitle),
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
              icon: Icons.star_rounded,
              foreground: colors.primary,
              onTap: () => Navigator.of(context).pop(days),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (isCurrentlyFeatured) ...[
            const SizedBox(height: AppSpacing.xs),
            _DurationTile(
              label: l10n.adminFeatureDialogRemove,
              icon: Icons.star_outline_rounded,
              foreground: colors.error,
              onTap: () => Navigator.of(context).pop(0),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminFeatureDialogCancel),
        ),
      ],
    );
  }
}

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
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
      ),
      leading: Icon(icon, color: foreground),
      title: Text(label, style: styles.bodyLarge.copyWith(color: foreground)),
      onTap: onTap,
    );
  }
}
