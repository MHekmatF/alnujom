import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../l10n/app_localizations.dart';

/// The listing-publish success celebration: a confetti burst over a card with
/// an animated success check, the success message, and a Continue button.
/// Resolves when the user taps Continue. Confetti + the check pop are skipped
/// under reduced motion (the check + message still show).
Future<void> showPublishSuccess(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PublishSuccessDialog(),
  );
}

class _PublishSuccessDialog extends StatefulWidget {
  const _PublishSuccessDialog();

  @override
  State<_PublishSuccessDialog> createState() => _PublishSuccessDialogState();
}

class _PublishSuccessDialogState extends State<_PublishSuccessDialog> {
  final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 2),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !reduceMotion(context)) {
      _started = true;
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final reduce = reduceMotion(context);

    Widget check = Container(
      width: AppSpacing.xxxl + AppSpacing.xl,
      height: AppSpacing.xxxl + AppSpacing.xl,
      decoration: BoxDecoration(
        color: colors.verifiedContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        size: AppSpacing.xxl,
        color: colors.verified,
      ),
    );
    if (!reduce) {
      check = check.animate().scaleXY(
        begin: 0.0,
        end: 1.0,
        duration: AppMotion.slow,
        curve: Curves.elasticOut,
      );
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Dialog(
          shape: RoundedRectangleBorder(borderRadius: appRadius(AppRadii.xl)),
          backgroundColor: colors.card,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                check,
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.listingFormSubmitSuccess,
                  textAlign: TextAlign.center,
                  style: styles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.listingFormSubmitSuccessSubtitle,
                  textAlign: TextAlign.center,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: l10n.listingFormContinueButton,
                    expanded: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!reduce)
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 18,
            gravity: 0.25,
            minimumSize: const Size(8, 8),
            maximumSize: const Size(14, 14),
            colors: [
              colors.primary,
              colors.accent,
              colors.verified,
              colors.tertiary,
            ],
          ),
      ],
    );
  }
}
