import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../routing/app_router.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'app_button.dart';
import '_widget_support.dart';

/// Which account-only destination a guest just reached for. Only used to pick
/// the sentence that explains what signing in would get them — the reason has
/// to be concrete ("keep the properties you save"), not a generic wall.
enum GuestGate { favorites, messages, profile, notifications, publish }

/// Shown when a signed-out visitor taps something that needs an account.
///
/// WHY THIS EXISTS — device walk, 2026-09-02. Three of the five bottom-bar
/// tabs called `context.go(login)` (or navigated to a protected route and let
/// the global redirect do it). `context.go` replaces the whole stack, so a
/// guest who tapped "Saved" out of curiosity lost their place, got no
/// explanation, and — because /login is then the only entry on the stack —
/// **pressing Back quit the app**. Verified on the device: three of five tabs
/// were a one-way exit.
///
/// So this does not navigate. It is a short sheet over wherever the guest
/// already was; dismissing it puts them back exactly there. Signing in is an
/// offer with a reason attached, not a toll gate.
Future<void> showGuestSignInSheet(
  BuildContext context, {
  required GuestGate gate,
}) {
  // No surface, shape or drag handle of its own — `bottomSheetTheme` already
  // supplies all three, and drawing a second handle on top of the themed one is
  // exactly what happened the first time this shipped.
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _GuestSignInSheet(gate: gate),
  );
}

class _GuestSignInSheet extends StatelessWidget {
  const _GuestSignInSheet({required this.gate});

  final GuestGate gate;

  String _reason(AppLocalizations l10n) => switch (gate) {
    GuestGate.favorites => l10n.guest_gate_reason_favorites,
    GuestGate.messages => l10n.guest_gate_reason_messages,
    GuestGate.profile => l10n.guest_gate_reason_profile,
    GuestGate.notifications => l10n.guest_gate_reason_notifications,
    GuestGate.publish => l10n.guest_gate_reason_publish,
  };

  IconData get _icon => switch (gate) {
    GuestGate.favorites => Icons.bookmark_outline,
    GuestGate.messages => Icons.forum_outlined,
    GuestGate.profile => Icons.person_outline,
    GuestGate.notifications => Icons.notifications_none,
    GuestGate.publish => Icons.add_home_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.lg,
          end: AppSpacing.lg,
          bottom: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: AppSpacing.xxl + AppSpacing.lg,
                height: AppSpacing.xxl + AppSpacing.lg,
                alignment: AlignmentDirectional.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: appRadius(AppRadii.lg),
                ),
                child: Icon(
                  _icon,
                  color: colors.primary,
                  size: AppSpacing.xl + AppSpacing.xs,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.guest_gate_title,
              style: styles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _reason(l10n),
              style: styles.bodyMedium.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.filledPrimary(
              label: l10n.guest_gate_sign_in,
              expanded: true,
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
                context.push(AppRoutes.login);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.guest_gate_register,
              variant: AppButtonVariant.outlined,
              expanded: true,
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
                context.push(AppRoutes.register);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: l10n.guest_gate_keep_browsing,
              variant: AppButtonVariant.text,
              expanded: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
