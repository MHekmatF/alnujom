// lib/features/inquiries/presentation/widgets/inquiry_message_snippet.dart
//
// Phase 16 Sub-Phase F (T066) — Truncates a message to ~120 chars + ellipsis.
// Token-only: muted body type so it reads as a last-message preview.
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class InquiryMessageSnippet extends StatelessWidget {
  const InquiryMessageSnippet({required this.message, super.key});

  final String message;

  static const int _maxChars = 120;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final snippet = message.length > _maxChars
        ? '${message.substring(0, _maxChars)}…'
        : message;

    return Text(
      snippet,
      style: styles.bodyMedium.copyWith(color: colors.textMuted),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
