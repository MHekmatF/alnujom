import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/theme/colors.dart';

/// A small, reassuring trust line shown beneath the auth forms (login /
/// register / reset) — a shield glyph + privacy reassurance copy in muted text.
class AuthTrustNote extends StatelessWidget {
  const AuthTrustNote({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.shield_check, size: AppSpacing.lg, color: colors.verified),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            text,
            style: styles.labelMedium.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
