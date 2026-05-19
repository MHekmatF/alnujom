import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../locations/presentation/widgets/location_picker.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import 'required_field_chip.dart';

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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Phase 8 LocationPicker reused verbatim per SC-021.
            // The picker emits a (governorate, city, area) selection; the
            // bloc translates each into a typed FieldChanged event.
            LocationPicker(
              areaRequired: true,
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
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  l10n.fieldLabelAddressText,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                const RequiredFieldChip(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _addressController,
              maxLines: 2,
              onChanged: (v) => context
                  .read<ListingFormBloc>()
                  .add(FieldChanged.addressText(v)),
              decoration: InputDecoration(
                hintText: l10n.fieldLabelAddressText,
                border: const OutlineInputBorder(),
              ),
            ),
            if (centroidError) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.validatorAreaMissingCentroid,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

