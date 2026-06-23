import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';

/// Phase 033 auth restyle — a centred status surface for the account-gate
/// screens (pending approval / publisher pending / rejected / suspended): a
/// glyph in a soft round token-tinted badge, an optional title, and a body
/// paragraph. Purely presentational; the hosting pages keep their bloc wiring
/// and sign-out actions.
class AuthStatusMessage extends StatelessWidget {
  const AuthStatusMessage({
    required this.icon,
    required this.message,
    this.title,
    this.tone = AuthStatusTone.neutral,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? title;
  final AuthStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final (badge, onBadge) = switch (tone) {
      AuthStatusTone.neutral => (colors.primaryContainer, colors.onPrimaryContainer),
      AuthStatusTone.warning => (colors.surfaceVariant, colors.warning),
      AuthStatusTone.error => (colors.surfaceVariant, colors.error),
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: AppSpacing.xxxl + AppSpacing.lg,
            height: AppSpacing.xxxl + AppSpacing.lg,
            decoration: BoxDecoration(shape: BoxShape.circle, color: badge),
            child: Icon(icon, size: AppSpacing.xxl, color: onBadge),
          ),
          if (title != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              title!,
              style: styles.headlineMedium.copyWith(color: colors.onSurface),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: styles.bodyLarge.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The badge accent applied to an [AuthStatusMessage]: a neutral brand tint, a
/// cautionary warning, or a blocking error.
enum AuthStatusTone { neutral, warning, error }
