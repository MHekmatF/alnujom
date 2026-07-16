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

/// What the user chose on the publish-success screen. Drives where the caller
/// navigates next.
enum PublishSuccessAction {
  /// View «My Listings» — see the freshly-submitted listing in the queue.
  viewListings,

  /// Start a brand-new listing.
  addAnother,
}

/// The listing-publish success moment (DC "Blue Crown" · FLOW A · Success): a
/// confetti burst over a card with an animated green check, the "submitted for
/// review" message, an «Under review» status pill, and two actions — view my
/// listings (primary) or add another. Resolves with the chosen
/// [PublishSuccessAction] (or `null` if dismissed via system back). Confetti +
/// the check pop are skipped under reduced motion.
Future<PublishSuccessAction?> showPublishSuccess(BuildContext context) {
  return showDialog<PublishSuccessAction>(
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
        Icons.check_circle_rounded,
        size: AppSpacing.xxl,
        color: colors.onSuccess,
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
                const SizedBox(height: AppSpacing.md),
                _UnderReviewChip(label: l10n.listingFormUnderReviewChip),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: l10n.myListingsPageTitle,
                    expanded: true,
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(PublishSuccessAction.viewListings),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: l10n.listingFormAddAnother,
                    variant: AppButtonVariant.outlined,
                    expanded: true,
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(PublishSuccessAction.addAnother),
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

/// The «Under review» status pill — a surface2 rounded chip with an hourglass
/// glyph, reinforcing that the listing is pending moderation (not yet live).
class _UnderReviewChip extends StatelessWidget {
  const _UnderReviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top, size: 16, color: colors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: styles.labelMedium.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
