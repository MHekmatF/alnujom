// lib/features/inquiries/presentation/widgets/unread_count_badge.dart
//
// Phase 16 Sub-Phase F (T067) — Small circular badge for unread inquiry count.
// Hidden when count == 0.
import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';

class UnreadCountBadge extends StatelessWidget {
  const UnreadCountBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      constraints: const BoxConstraints(
        minWidth: AppSpacing.lg,
        minHeight: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.error,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onError,
          fontSize: 10,
        ),
      ),
    );
  }
}
