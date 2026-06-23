// lib/features/inquiries/presentation/widgets/unread_count_badge.dart
//
// Phase 16 Sub-Phase F (T067) — Small badge for the unread inquiry count.
// Restyled to the royal-blue DS: a brand-primary pill with on-primary ink.
// Hidden when count == 0. Token-only (no raw colors / TextStyle).
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';

class UnreadCountBadge extends StatelessWidget {
  const UnreadCountBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      constraints: const BoxConstraints(
        minWidth: AppSpacing.lg,
        minHeight: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        borderRadius: appRadius(AppRadii.pill),
        color: colors.primary,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: styles.labelMedium.copyWith(
          color: colors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
