import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

enum ChatBubbleVariant { mine, theirs }

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    required this.message,
    this.variant = ChatBubbleVariant.theirs,
    super.key,
  });

  final String message;
  final ChatBubbleVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final mine = variant == ChatBubbleVariant.mine;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: AppSurface(
        color: mine ? colors.primary : colors.card,
        borderColor: mine ? colors.primary : colors.outline,
        radius: AppRadii.lg,
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Text(
          message,
          style: styles.bodyLarge.copyWith(
            color: mine ? colors.onPrimary : colors.onSurface,
          ),
        ),
      ),
    );
  }
}
