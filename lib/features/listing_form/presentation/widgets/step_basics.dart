import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../agency/presentation/widgets/publish_under_agency_field.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import '../util/listing_enum_labels.dart';
import 'step_section.dart';

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
        return StepSection(
          icon: Icons.home_work_outlined,
          title: l10n.listingFormStepBasicsTitle,
          subtitle: l10n.listingFormStepBasicsSubtitle,
          children: [
            FieldLabel(label: l10n.fieldLabelTitle, required: true),
            TextField(
              controller: _titleController,
              // Phase 029 (F3 #5) — keyboard polish: keep the focused field
              // visible above the keyboard and advance focus on submit.
              scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              onChanged: (v) =>
                  context.read<ListingFormBloc>().add(FieldChanged.title(v)),
              decoration: InputDecoration(
                hintText: l10n.fieldLabelTitle,
                border: const OutlineInputBorder(),
              ),
            ),
            const FieldGap(),
            FieldLabel(label: l10n.fieldLabelPurpose, required: true),
            DropdownButtonFormField<ListingPurpose>(
              initialValue: listing.purpose,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: ListingPurpose.values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(listingPurposeLabel(p, l10n)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  context.read<ListingFormBloc>().add(FieldChanged.purpose(v));
                }
              },
            ),
            const FieldGap(),
            FieldLabel(label: l10n.fieldLabelPropertyType, required: true),
            DropdownButtonFormField<PropertyType>(
              initialValue: listing.propertyType,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: PropertyType.values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(propertyTypeLabel(p, l10n)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  context.read<ListingFormBloc>().add(
                    FieldChanged.propertyType(v),
                  );
                }
              },
            ),
            // Phase 19 (T062) — publish-under-agency selector. Renders nothing
            // when the user has no eligible agency (no reflow for personal).
            PublishUnderAgencyField(
              agencies: state.availableAgencies,
              selectedAgencyId: listing.agencyId,
              onChanged: (agencyId) => context
                  .read<ListingFormBloc>()
                  .add(FieldChanged.agencyId(agencyId)),
            ),
          ],
        );
      },
    );
  }
}
