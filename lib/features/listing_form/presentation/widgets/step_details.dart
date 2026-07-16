import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/validators/area_size_validator.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import 'express_form_fields.dart' show expressDecoration;
import 'step_section.dart';

const List<String> kAmenitiesCatalog = <String>[
  'elevator',
  'balcony',
  'swimming_pool',
  'garden',
  'security',
  'generator',
  'solar_panels',
  'central_heating',
  'air_conditioning',
  'furnished_kitchen',
];

class StepDetails extends StatefulWidget {
  const StepDetails({super.key});

  @override
  State<StepDetails> createState() => _StepDetailsState();
}

class _StepDetailsState extends State<StepDetails> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _areaSizeController = TextEditingController();
  final TextEditingController _roomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _yearBuiltController = TextEditingController();
  bool _seeded = false;
  String? _areaSizeError;

  @override
  void dispose() {
    _descriptionController.dispose();
    _areaSizeController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _floorController.dispose();
    _yearBuiltController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final listing = state.draftListing;
        final details = state.draftDetails;
        if (listing == null) return const SizedBox.shrink();
        if (!_seeded) {
          _descriptionController.text = details?.description ?? '';
          _areaSizeController.text =
              listing.areaSize?.toString().replaceAll(RegExp(r'\.0$'), '') ??
              '';
          _roomsController.text = listing.rooms?.toString() ?? '';
          _bathroomsController.text = listing.bathrooms?.toString() ?? '';
          _floorController.text = listing.floor?.toString() ?? '';
          _yearBuiltController.text = details?.yearBuilt?.toString() ?? '';
          _seeded = true;
        }
        final showRoomsBathrooms = listing.propertyType.isResidential;
        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepSection(
              icon: Icons.description_outlined,
              title: l10n.listingFormStepDetailsTitle,
              subtitle: l10n.listingFormStepDetailsSubtitle,
              children: [
                FieldLabel(label: l10n.fieldLabelDescription),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  // Phase 029 (F3 #5) — keep the focused multiline field above
                  // the keyboard. (No textInputAction.next on multiline — the
                  // newline key stays as the action.)
                  scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
                  onChanged: (v) => context.read<ListingFormBloc>().add(
                    FieldChanged.description(v),
                  ),
                  decoration: expressDecoration(context, collapseHeight: true),
                ),
                const FieldGap(),
                FieldLabel(label: l10n.fieldLabelAreaSize, required: true),
                TextField(
                  controller: _areaSizeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // Phase 029 (F3 #5) — keyboard polish.
                  scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: expressDecoration(context, error: _areaSizeError),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    final error = AreaSizeValidator.validate(parsed, l10n);
                    setState(() => _areaSizeError = error);
                    context.read<ListingFormBloc>().add(
                      FieldChanged.areaSize(parsed),
                    );
                  },
                ),
                if (showRoomsBathrooms) ...[
                  const FieldGap(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _numericField(
                          controller: _roomsController,
                          label: l10n.fieldLabelRooms,
                          onParsed: (i) => context.read<ListingFormBloc>().add(
                            FieldChanged.rooms(i),
                          ),
                          required: true,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _numericField(
                          controller: _bathroomsController,
                          label: l10n.fieldLabelBathrooms,
                          onParsed: (i) => context.read<ListingFormBloc>().add(
                            FieldChanged.bathrooms(i),
                          ),
                          required: true,
                        ),
                      ),
                    ],
                  ),
                ],
                const FieldGap(),
                _numericField(
                  controller: _floorController,
                  label: l10n.fieldLabelFloor,
                  onParsed: (i) => context.read<ListingFormBloc>().add(
                    FieldChanged.floor(i),
                  ),
                ),
                const FieldGap(),
                _numericField(
                  controller: _yearBuiltController,
                  label: l10n.fieldLabelYearBuilt,
                  onParsed: (i) => context.read<ListingFormBloc>().add(
                    FieldChanged.yearBuilt(i),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            StepSection(
              icon: Icons.star_outline,
              title: l10n.fieldLabelAmenities,
              subtitle: l10n.listingFormDetailsFeaturesSubtitle,
              children: [
                SwitchListTile(
                  title: Text(
                    l10n.fieldLabelFurnished,
                    style: styles.bodyLarge.copyWith(color: colors.onSurface),
                  ),
                  value: details?.furnished ?? false,
                  onChanged: (v) => context.read<ListingFormBloc>().add(
                    FieldChanged.furnished(v),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: Text(
                    l10n.fieldLabelParking,
                    style: styles.bodyLarge.copyWith(color: colors.onSurface),
                  ),
                  value: details?.parking ?? false,
                  onChanged: (v) => context.read<ListingFormBloc>().add(
                    FieldChanged.parking(v),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const FieldGap(),
                FieldLabel(label: l10n.fieldLabelAmenities),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: kAmenitiesCatalog.map((key) {
                    final selected = details?.amenities.contains(key) ?? false;
                    return FilterChip(
                      label: Text(_amenityLabel(key, l10n)),
                      selected: selected,
                      onSelected: (val) {
                        final current = List<String>.from(
                          details?.amenities ?? const <String>[],
                        );
                        if (val) {
                          if (!current.contains(key)) current.add(key);
                        } else {
                          current.remove(key);
                        }
                        context.read<ListingFormBloc>().add(
                          FieldChanged.amenities(current),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _numericField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<int?> onParsed,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label: label, required: required),
        Builder(
          builder: (context) => TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            // Phase 029 (F3 #5) — keyboard polish.
            scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: expressDecoration(context),
            onChanged: (v) {
              final parsed = int.tryParse(v);
              onParsed(parsed);
            },
          ),
        ),
      ],
    );
  }

  String _amenityLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'elevator':
        return l10n.amenityElevator;
      case 'balcony':
        return l10n.amenityBalcony;
      case 'swimming_pool':
        return l10n.amenitySwimmingPool;
      case 'garden':
        return l10n.amenityGarden;
      case 'security':
        return l10n.amenitySecurity;
      case 'generator':
        return l10n.amenityGenerator;
      case 'solar_panels':
        return l10n.amenitySolarPanels;
      case 'central_heating':
        return l10n.amenityCentralHeating;
      case 'air_conditioning':
        return l10n.amenityAirConditioning;
      case 'furnished_kitchen':
        return l10n.amenityFurnishedKitchen;
      default:
        return key;
    }
  }
}
