import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../locations/domain/entities/location_picker_selection.dart';
import '../../../locations/presentation/widgets/location_picker.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import 'step_section.dart';

class StepLocation extends StatefulWidget {
  const StepLocation({super.key});

  @override
  State<StepLocation> createState() => _StepLocationState();
}

class _StepLocationState extends State<StepLocation> {
  final TextEditingController _addressController = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        if (!_seeded) {
          _addressController.text = listing.addressText ?? '';
          _seeded = true;
        }
        final centroidError =
            state.stepValidationErrors['location.centroid'] != null;
        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);
        return StepSection(
          icon: Icons.location_on_outlined,
          title: l10n.listingFormStepLocationTitle,
          subtitle: l10n.listingFormStepLocationSubtitle,
          children: [
            // Phase 8 LocationPicker reused verbatim per SC-021.
            // The picker emits a (governorate, city, area) selection; the
            // bloc translates each into a typed FieldChanged event.
            // initialSelection seeds the dropdowns from the loaded listing
            // (edit-mode / Resubmit on a rejected listing).
            LocationPicker(
              areaRequired: true,
              initialSelection:
                  (listing.governorateId != null && listing.cityId != null)
                  ? LocationPickerSelection(
                      governorateId: listing.governorateId!,
                      cityId: listing.cityId!,
                      areaId: listing.areaId,
                    )
                  : null,
              onChanged: (selection) {
                final bloc = context.read<ListingFormBloc>();
                final gov = selection?.governorateId;
                final city = selection?.cityId;
                final area = selection?.areaId;
                // Bloc deduplicates internally via state equality; firing
                // three events on every change is fine.
                bloc.add(FieldChanged.governorateId(gov));
                bloc.add(FieldChanged.cityId(city));
                bloc.add(FieldChanged.areaId(area));
              },
            ),
            const FieldGap(),
            FieldLabel(label: l10n.fieldLabelAddressText, required: true),
            TextField(
              controller: _addressController,
              maxLines: 2,
              onChanged: (v) => context.read<ListingFormBloc>().add(
                FieldChanged.addressText(v),
              ),
              decoration: InputDecoration(
                hintText: l10n.fieldLabelAddressText,
                border: const OutlineInputBorder(),
              ),
            ),
            if (centroidError) ...[
              const FieldGap(),
              Container(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  borderRadius: appRadius(AppRadii.md),
                  border: Border.all(color: colors.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: AppSpacing.lg,
                      color: colors.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.validatorAreaMissingCentroid,
                        style: styles.bodyMedium.copyWith(color: colors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
