import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import 'required_field_chip.dart';

class StepBasics extends StatefulWidget {
  const StepBasics({super.key});

  @override
  State<StepBasics> createState() => _StepBasicsState();
}

class _StepBasicsState extends State<StepBasics> {
  final TextEditingController _titleController = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _titleController.dispose();
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
          _titleController.text = listing.title;
          _seeded = true;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  l10n.fieldLabelTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                const RequiredFieldChip(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _titleController,
              onChanged: (v) => context
                  .read<ListingFormBloc>()
                  .add(FieldChanged.title(v)),
              decoration: InputDecoration(
                hintText: l10n.fieldLabelTitle,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  l10n.fieldLabelPurpose,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                const RequiredFieldChip(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<ListingPurpose>(
              initialValue: listing.purpose,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: ListingPurpose.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(_purposeLabel(p, l10n)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  context
                      .read<ListingFormBloc>()
                      .add(FieldChanged.purpose(v));
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  l10n.fieldLabelPropertyType,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                const RequiredFieldChip(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<PropertyType>(
              initialValue: listing.propertyType,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: PropertyType.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(_propertyTypeLabel(p, l10n)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  context
                      .read<ListingFormBloc>()
                      .add(FieldChanged.propertyType(v));
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _purposeLabel(ListingPurpose p, AppLocalizations l10n) {
    switch (p) {
      case ListingPurpose.sale:
        return l10n.listingPurposeSale;
      case ListingPurpose.rent:
        return l10n.listingPurposeRent;
      case ListingPurpose.dailyRent:
        return l10n.listingPurposeDailyRent;
      case ListingPurpose.investment:
        return l10n.listingPurposeInvestment;
    }
  }

  String _propertyTypeLabel(PropertyType p, AppLocalizations l10n) {
    switch (p) {
      case PropertyType.apartment:
        return l10n.propertyTypeApartment;
      case PropertyType.villa:
        return l10n.propertyTypeVilla;
      case PropertyType.land:
        return l10n.propertyTypeLand;
      case PropertyType.shop:
        return l10n.propertyTypeShop;
      case PropertyType.office:
        return l10n.propertyTypeOffice;
      case PropertyType.farm:
        return l10n.propertyTypeFarm;
      case PropertyType.warehouse:
        return l10n.propertyTypeWarehouse;
      case PropertyType.other:
        return l10n.propertyTypeOther;
    }
  }
}
