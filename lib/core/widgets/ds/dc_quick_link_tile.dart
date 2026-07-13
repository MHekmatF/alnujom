import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';

/// DC "Blue Crown" quick-link tile (`AlNujom - Publisher.dc.html` «إدارة النشاط»).
///
/// A flat card tile for a 3-column grid: a 44px tonal icon chip (optionally
/// carrying a red count badge) over a centred label. [label] and [badgeLabel]
/// are pre-localized/formatted by the caller.
class DcQuickLinkTile extends StatelessWidget {
  const DcQuickLinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeLabel,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Optional red count badge (already localized, e.g. "2"). Null → no badge.
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: appRadius(AppRadii.lg),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: appRadius(AppRadii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: appRadius(AppRadii.md),
                    ),
                    child: Icon(
                      icon,
                      size: 23,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  if (badgeLabel != null)
                    PositionedDirectional(
                      top: -5,
                      end: -5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        alignment: Alignment.center,
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.error,
                          borderRadius: appRadius(AppRadii.pill),
                          border: Border.all(color: colors.card, width: 2),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: styles.labelSmall.copyWith(
                            color: colors.onError,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: styles.labelSmall.copyWith(color: colors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
