import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';

class StepReview extends StatelessWidget {
  const StepReview({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        final details = state.draftDetails;
        final price = state.draftPrice;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Section(
              title: l10n.listingFormStepBasicsTitle,
              onEdit: () => context
                  .read<ListingFormBloc>()
                  .add(const JumpToStep(ListingFormStep.basics)),
              rows: [
                (l10n.fieldLabelTitle, listing.title),
                (l10n.fieldLabelPurpose, listing.purpose.name),
                (l10n.fieldLabelPropertyType, listing.propertyType.name),
              ],
            ),
            _Section(
              title: l10n.listingFormStepLocationTitle,
              onEdit: () => context
                  .read<ListingFormBloc>()
                  .add(const JumpToStep(ListingFormStep.location)),
              rows: [
                (l10n.fieldLabelGovernorate, listing.governorateId ?? '—'),
                (l10n.fieldLabelCity, listing.cityId ?? '—'),
                (l10n.fieldLabelArea, listing.areaId ?? '—'),
                (l10n.fieldLabelAddressText, listing.addressText ?? '—'),
              ],
            ),
            _Section(
              title: l10n.listingFormStepDetailsTitle,
              onEdit: () => context
                  .read<ListingFormBloc>()
                  .add(const JumpToStep(ListingFormStep.details)),
              rows: [
                (l10n.fieldLabelAreaSize, listing.areaSize?.toString() ?? '—'),
                if (listing.propertyType.name == 'apartment' ||
                    listing.propertyType.name == 'villa') ...[
                  (l10n.fieldLabelRooms, listing.rooms?.toString() ?? '—'),
                  (l10n.fieldLabelBathrooms,
                      listing.bathrooms?.toString() ?? '—'),
                ],
                (l10n.fieldLabelFloor, listing.floor?.toString() ?? '—'),
                (l10n.fieldLabelDescription, details?.description ?? '—'),
                (
                  l10n.fieldLabelAmenities,
                  (details?.amenities ?? const <String>[]).join(', ')
                ),
              ],
            ),
            _Section(
              title: l10n.listingFormStepPricesTitle,
              onEdit: () => context
                  .read<ListingFormBloc>()
                  .add(const JumpToStep(ListingFormStep.prices)),
              rows: [
                (l10n.fieldLabelCurrency, price?.currencyCode ?? '—'),
                (l10n.fieldLabelPrice, price?.amount.toString() ?? '—'),
              ],
            ),
            _Section(
              title: l10n.listingFormStepVisibilityTitle,
              onEdit: () => context
                  .read<ListingFormBloc>()
                  .add(const JumpToStep(ListingFormStep.visibility)),
              rows: [
                (l10n.fieldLabelLocationVisibility,
                    listing.locationVisibility.name),
                (l10n.fieldLabelContactNameVisibility,
                    listing.contactNameVisibility.name),
                (l10n.fieldLabelPhone, listing.phone ?? '—'),
                (l10n.fieldLabelWhatsapp, listing.whatsapp ?? '—'),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    required this.onEdit,
  });

  final String title;
  final List<(String, String)> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: Text(l10n.listingFormJumpToStepButton),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          row.$1,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.$2.isEmpty ? '—' : row.$2,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
