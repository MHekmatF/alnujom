import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing_form_state.dart';
import '../../domain/entities/submit_failure.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';

class SubmitFailureDialog extends StatelessWidget {
  const SubmitFailureDialog({super.key, required this.failure});

  final SubmitFailure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return AlertDialog(
      icon: Icon(Icons.error_outline, color: colors.error, size: AppSpacing.xxl),
      title: Text(l10n.submitFailureTitle, style: styles.titleLarge),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (failure.hasMissingFields) ...[
            Text(
              l10n.submitFailureMissingFieldsHeader,
              style: styles.bodyMedium.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            ...failure.missingFields.map(
              (path) => Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppSpacing.xs,
                ),
                child: Container(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.08),
                    borderRadius: appRadius(AppRadii.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: AppSpacing.sm,
                        color: colors.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _labelForPath(path, l10n),
                          style: styles.bodyLarge.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      AppButton(
                        label: l10n.listingFormJumpToStepButton,
                        variant: AppButtonVariant.text,
                        size: AppButtonSize.dense,
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.read<ListingFormBloc>().add(
                            JumpToStep(_stepForPath(path)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (failure.userFacingMessage != null) ...[
            Text(
              failure.userFacingMessage!,
              style: styles.bodyLarge.copyWith(color: colors.onSurface),
            ),
          ] else ...[
            Text(
              l10n.submitErrorUnknown,
              style: styles.bodyLarge.copyWith(color: colors.onSurface),
            ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: l10n.actionDismiss,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// Maps a dot-notated missing-field path to its localized label.
  static String _labelForPath(String path, AppLocalizations l10n) {
    switch (path) {
      case 'listings.title':
        return l10n.missingFieldListingsTitle;
      case 'listings.purpose':
        return l10n.missingFieldListingsPurpose;
      case 'listings.property_type':
        return l10n.missingFieldListingsPropertyType;
      case 'listings.governorate_id':
        return l10n.missingFieldListingsGovernorateId;
      case 'listings.city_id':
        return l10n.missingFieldListingsCityId;
      case 'listings.area_id':
        return l10n.missingFieldListingsAreaId;
      case 'listings.address_text':
        return l10n.missingFieldListingsAddressText;
      case 'listings.area_size':
        return l10n.missingFieldListingsAreaSize;
      case 'listings.rooms':
        return l10n.missingFieldListingsRooms;
      case 'listings.bathrooms':
        return l10n.missingFieldListingsBathrooms;
      case 'listings.phone_or_whatsapp':
        return l10n.missingFieldListingsPhoneOrWhatsapp;
      case 'listing_prices.primary':
        return l10n.missingFieldListingPricesPrimary;
      default:
        return path;
    }
  }

  /// Maps a dot-notated missing-field path back to the step it lives on,
  /// so the "Jump to step" CTA can navigate the publisher straight to it.
  static ListingFormStep _stepForPath(String path) {
    if (path.startsWith('listings.title') ||
        path.startsWith('listings.purpose') ||
        path.startsWith('listings.property_type')) {
      return ListingFormStep.basics;
    }
    if (path.startsWith('listings.governorate_id') ||
        path.startsWith('listings.city_id') ||
        path.startsWith('listings.area_id') ||
        path.startsWith('listings.address_text')) {
      return ListingFormStep.location;
    }
    if (path.startsWith('listings.area_size') ||
        path.startsWith('listings.rooms') ||
        path.startsWith('listings.bathrooms')) {
      return ListingFormStep.details;
    }
    if (path.startsWith('listing_prices')) {
      return ListingFormStep.prices;
    }
    if (path.startsWith('listings.phone_or_whatsapp')) {
      return ListingFormStep.visibility;
    }
    return ListingFormStep.basics;
  }
}
