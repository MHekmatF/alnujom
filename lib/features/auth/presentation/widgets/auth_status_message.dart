import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/staggered_list_item.dart';

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
    this.action,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? title;
  final AuthStatusTone tone;

  /// Optional in-content CTA rendered below the message (e.g. a sign-out
  /// button on the terminal rejected/suspended gate screens). Defaults to
  /// null, so the pending/publisher-pending pages are unchanged.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final (badge, onBadge) = switch (tone) {
      AuthStatusTone.neutral => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      AuthStatusTone.warning => (
        colors.warning.withValues(alpha: 0.12),
        colors.warning,
      ),
      AuthStatusTone.error => (
        colors.error.withValues(alpha: 0.12),
        colors.error,
      ),
    };

    return Center(
      child: StaggeredListItem(
        index: 0,
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
              Semantics(
                header: true,
                child: Text(
                  title!,
                  style: styles.headlineMedium.copyWith(
                    color: colors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: styles.bodyLarge.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The badge accent applied to an [AuthStatusMessage]: a neutral brand tint, a
/// cautionary warning, or a blocking error.
enum AuthStatusTone { neutral, warning, error }
