import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';

/// Premium uplift — buyer-safety reassurance banner.
///
/// A subtle, branded info card (a shield glyph in a soft-tinted container +
/// reassurance copy) shown just above the contact section so the buyer reads it
/// before reaching out. Purely informational — no actions, no behavior.
///
/// Token-only (no inline hex / TextStyle / numeric insets). RTL-safe via
/// [EdgeInsetsDirectional] + a leading/trailing [Row].
class BuyerSafetyBanner extends StatelessWidget {
  const BuyerSafetyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        // A whisper-soft brand wash so the note reads as reassurance, not alarm.
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: appRadius(AppRadii.md),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Soft-tinted icon chip — the brand "shield" reassurance mark.
          Container(
            padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: appRadius(AppRadii.sm),
            ),
            child: Icon(
              LucideIcons.shield_check,
              size: AppSpacing.xl,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.listing_details_buyer_safety_note,
              style: styles.bodyMedium.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
