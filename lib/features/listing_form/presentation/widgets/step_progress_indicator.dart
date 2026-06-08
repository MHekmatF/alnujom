import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing_form_state.dart';

/// Phase 25 uplift — a polished segmented stepper for the add-listing flow.
///
/// Renders a "Step X of Y · <title>" caption above a row of rounded segments
/// that fill from the start: done + current segments use the brand primary,
/// upcoming segments use the muted outline tone. The current segment animates
/// to its filled state (skipped under reduced motion). Keeps the existing step
/// model — the [currentStep] index drives the fill.
class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({super.key, required this.currentStep});

  final ListingFormStep currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final reduce = reduceMotion(context);
    final total = ListingFormStep.values.length;
    final currentIndex = currentStep.index0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.listingFormStepCounter(
            currentIndex + 1,
            total,
            _titleForStep(currentStep, l10n),
          ),
          style: styles.labelMedium.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List<Widget>.generate(total, (i) {
            final done = i <= currentIndex;
            final segment = AnimatedContainer(
              duration: reduce ? Duration.zero : AppMotion.base,
              curve: AppMotion.curve,
              height: AppSpacing.sm,
              decoration: BoxDecoration(
                color: done ? colors.primary : colors.outline,
                borderRadius: appRadius(AppRadii.pill),
              ),
            );
            return Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                child: i == total - 1
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.xs,
                        ),
                        child: segment,
                      )
                    : segment,
              ),
            );
          }),
        ),
      ],
    );
  }

  String _titleForStep(ListingFormStep step, AppLocalizations l10n) {
    switch (step) {
      case ListingFormStep.basics:
        return l10n.listingFormStepBasicsTitle;
      case ListingFormStep.location:
        return l10n.listingFormStepLocationTitle;
      case ListingFormStep.details:
        return l10n.listingFormStepDetailsTitle;
      case ListingFormStep.prices:
        return l10n.listingFormStepPricesTitle;
      case ListingFormStep.visibility:
        return l10n.listingFormStepVisibilityTitle;
      case ListingFormStep.media:
        return l10n.listingFormStepMediaTitle;
      case ListingFormStep.review:
        return l10n.listingFormStepReviewTitle;
    }
  }
}
