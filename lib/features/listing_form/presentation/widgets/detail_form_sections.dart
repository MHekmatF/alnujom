import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/validators/area_size_validator.dart';
import '../../../../core/validators/phone_validator.dart';
import '../../../../core/validators/price_validator.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../currencies/domain/usecases/list_currencies.dart';
import '../../../locations/domain/entities/location_picker_selection.dart';
import '../../../locations/presentation/widgets/location_picker.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import '../util/listing_enum_labels.dart';
import 'express_form_fields.dart' show expressDecoration;
import 'step_details.dart' show kAmenitiesCatalog;
import 'step_section.dart';

/// Phase 031 (WS-A) — section widgets for the detail-style CREATE form.
///
/// Each widget is an EDITABLE counterpart of a read-only block on the
/// listing-details page, wrapped in the same [StepSection] (AppSurface + icon
/// badge + header) the stepper uses, so the single-scroll form reads as "fill
/// in your listing the way buyers will see it". Every control dispatches the
/// EXISTING [FieldChanged] events on the EXISTING [ListingFormBloc] in create
/// mode — no new events, no bloc edits. The field-control idioms are copied
/// (not imported) from the private `step_*` widgets so this flow stays fully
/// decoupled from the stepper widgets (sibling-owned).

/// Title section — mirrors the details-page headline.
class DetailFormTitleSection extends StatefulWidget {
  const DetailFormTitleSection({super.key});

  @override
  State<DetailFormTitleSection> createState() => _DetailFormTitleSectionState();
}

class _DetailFormTitleSectionState extends State<DetailFormTitleSection> {
  final TextEditingController _controller = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      buildWhen: (p, n) => p.draftListing == null && n.draftListing != null,
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        if (!_seeded) {
          _controller.text = listing.title;
          _seeded = true;
        }
        return StepSection(
          icon: Icons.title_outlined,
          title: l10n.formDetailTitleSectionTitle,
          subtitle: l10n.formDetailTitleSectionSubtitle,
          children: [
            FieldLabel(label: l10n.fieldLabelTitle, required: true),
            TextField(
              controller: _controller,
              scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              onChanged: (v) =>
                  context.read<ListingFormBloc>().add(FieldChanged.title(v)),
              decoration: expressDecoration(context, hint: l10n.fieldLabelTitle),
            ),
          ],
        );
      },
    );
  }
}

/// Purpose + property-type section — the two classifier dropdowns shown under
/// the title on the details page.
class DetailFormClassificationSection extends StatelessWidget {
  const DetailFormClassificationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      buildWhen: (p, n) =>
          p.draftListing?.purpose != n.draftListing?.purpose ||
          p.draftListing?.propertyType != n.draftListing?.propertyType,
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        final colors = AppColors.of(context);
        return StepSection(
          icon: Icons.category_outlined,
          title: l10n.formDetailClassificationSectionTitle,
          subtitle: l10n.formDetailClassificationSectionSubtitle,
          children: [
            FieldLabel(label: l10n.fieldLabelPurpose, required: true),
            DropdownButtonFormField<ListingPurpose>(
              initialValue: listing.purpose,
              isExpanded: true,
              decoration: expressDecoration(context),
              icon: Icon(Icons.expand_more, color: colors.textMuted),
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
              decoration: expressDecoration(context),
              icon: Icon(Icons.expand_more, color: colors.textMuted),
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
          ],
        );
      },
    );
  }
}

/// Price section — currency dropdown + amount, mirroring the details-page price
/// block. Copies the [_currenciesFuture] + dropdown idiom from `step_prices`.
class DetailFormPriceSection extends StatefulWidget {
  const DetailFormPriceSection({super.key});

  @override
  State<DetailFormPriceSection> createState() => _DetailFormPriceSectionState();
}

class _DetailFormPriceSectionState extends State<DetailFormPriceSection> {
  final TextEditingController _amountController = TextEditingController();
  Future<List<Currency>>? _currenciesFuture;
  bool _seeded = false;
  bool _currencyAutoSelected = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _currenciesFuture = getIt<ListCurrencies>().call(activeOnly: true);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final price = state.draftPrice;
        if (!_seeded && price != null) {
          _amountController.text = price.amount.toString();
          _seeded = true;
        }
        return FutureBuilder<List<Currency>>(
          future: _currenciesFuture,
          builder: (context, snap) {
            if (!snap.hasData) {
              return StepSection(
                icon: Icons.payments_outlined,
                title: l10n.formDetailPriceSectionTitle,
                subtitle: l10n.formDetailPriceSectionSubtitle,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Center(child: appInlineSpinner(context)),
                  ),
                ],
              );
            }
            final currencies = snap.data!;
            final selected = currencies.firstWhere(
              (c) => c.code == price?.currencyCode,
              orElse: () => currencies.first,
            );
            if (!_currencyAutoSelected && price == null) {
              _currencyAutoSelected = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                context.read<ListingFormBloc>().add(
                  FieldChanged.priceCurrencyCode(selected.code),
                );
              });
            }
            final colors = AppColors.of(context);
            return StepSection(
              icon: Icons.payments_outlined,
              title: l10n.formDetailPriceSectionTitle,
              subtitle: l10n.formDetailPriceSectionSubtitle,
              children: [
                FieldLabel(label: l10n.fieldLabelCurrency, required: true),
                DropdownButtonFormField<String>(
                  initialValue: price?.currencyCode ?? selected.code,
                  isExpanded: true,
                  decoration: expressDecoration(context),
                  icon: Icon(Icons.expand_more, color: colors.textMuted),
                  items: currencies
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(
                            l10n.currencyDropdownOption(c.code, c.symbol),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      context.read<ListingFormBloc>().add(
                        FieldChanged.priceCurrencyCode(v),
                      );
                    }
                  },
                ),
                const FieldGap(),
                FieldLabel(label: l10n.fieldLabelPrice, required: true),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: expressDecoration(context, error: _amountError),
                  onChanged: (v) {
                    final parsed = Decimal.tryParse(v);
                    final activeCurrency = currencies.firstWhere(
                      (c) => c.code == (price?.currencyCode ?? selected.code),
                      orElse: () => selected,
                    );
                    final error = PriceValidator.validate(
                      parsed,
                      activeCurrency,
                      l10n,
                    );
                    setState(() => _amountError = error);
                    if (parsed != null) {
                      context.read<ListingFormBloc>().add(
                        FieldChanged.priceAmount(parsed),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Location section — reuses the Phase 8 [LocationPicker] verbatim plus the
/// address field, mirroring the details-page location block.
class DetailFormLocationSection extends StatefulWidget {
  const DetailFormLocationSection({super.key});

  @override
  State<DetailFormLocationSection> createState() =>
      _DetailFormLocationSectionState();
}

class _DetailFormLocationSectionState extends State<DetailFormLocationSection> {
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
        return StepSection(
          icon: Icons.location_on_outlined,
          title: l10n.formDetailLocationSectionTitle,
          subtitle: l10n.formDetailLocationSectionSubtitle,
          children: [
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
                bloc.add(FieldChanged.governorateId(selection?.governorateId));
                bloc.add(FieldChanged.cityId(selection?.cityId));
                bloc.add(FieldChanged.areaId(selection?.areaId));
              },
            ),
            const FieldGap(),
            FieldLabel(label: l10n.fieldLabelAddressText, required: true),
            TextField(
              controller: _addressController,
              maxLines: 2,
              scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
              onChanged: (v) => context.read<ListingFormBloc>().add(
                FieldChanged.addressText(v),
              ),
              decoration: expressDecoration(context, collapseHeight: true),
            ),
          ],
        );
      },
    );
  }
}

/// Facts section — rooms / bathrooms / area / floor, mirroring the details-page
/// key-facts grid. Copies the numeric-field idiom from `step_details`.
class DetailFormFactsSection extends StatefulWidget {
  const DetailFormFactsSection({super.key});

  @override
  State<DetailFormFactsSection> createState() => _DetailFormFactsSectionState();
}

class _DetailFormFactsSectionState extends State<DetailFormFactsSection> {
  final TextEditingController _areaSizeController = TextEditingController();
  final TextEditingController _roomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  bool _seeded = false;
  String? _areaSizeError;

  @override
  void dispose() {
    _areaSizeController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      buildWhen: (p, n) =>
          (p.draftListing == null) != (n.draftListing == null) ||
          p.draftListing?.propertyType != n.draftListing?.propertyType,
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        if (!_seeded) {
          _areaSizeController.text =
              listing.areaSize?.toString().replaceAll(RegExp(r'\.0$'), '') ??
              '';
          _roomsController.text = listing.rooms?.toString() ?? '';
          _bathroomsController.text = listing.bathrooms?.toString() ?? '';
          _floorController.text = listing.floor?.toString() ?? '';
          _seeded = true;
        }
        final showRoomsBathrooms = listing.propertyType.isResidential;
        return StepSection(
          icon: Icons.straighten_outlined,
          title: l10n.formDetailFactsSectionTitle,
          subtitle: l10n.formDetailFactsSectionSubtitle,
          children: [
            FieldLabel(label: l10n.fieldLabelAreaSize, required: true),
            TextField(
              controller: _areaSizeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                    child: _DetailNumericField(
                      controller: _roomsController,
                      label: l10n.fieldLabelRooms,
                      required: true,
                      onParsed: (i) => context.read<ListingFormBloc>().add(
                        FieldChanged.rooms(i),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _DetailNumericField(
                      controller: _bathroomsController,
                      label: l10n.fieldLabelBathrooms,
                      required: true,
                      onParsed: (i) => context.read<ListingFormBloc>().add(
                        FieldChanged.bathrooms(i),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const FieldGap(),
            _DetailNumericField(
              controller: _floorController,
              label: l10n.fieldLabelFloor,
              onParsed: (i) => context.read<ListingFormBloc>().add(
                FieldChanged.floor(i),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DetailNumericField extends StatelessWidget {
  const _DetailNumericField({
    required this.controller,
    required this.label,
    required this.onParsed,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<int?> onParsed;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label: label, required: required),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: expressDecoration(context),
          onChanged: (v) => onParsed(int.tryParse(v)),
        ),
      ],
    );
  }
}

/// Amenities section — furnished / parking switches + the [kAmenitiesCatalog]
/// chips, mirroring the details-page amenities block.
class DetailFormAmenitiesSection extends StatelessWidget {
  const DetailFormAmenitiesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        final details = state.draftDetails;
        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);
        return StepSection(
          icon: Icons.star_outline,
          title: l10n.formDetailAmenitiesSectionTitle,
          subtitle: l10n.formDetailAmenitiesSectionSubtitle,
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
        );
      },
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

/// Description section — the long-form body, mirroring the details-page
/// description block.
class DetailFormDescriptionSection extends StatefulWidget {
  const DetailFormDescriptionSection({super.key});

  @override
  State<DetailFormDescriptionSection> createState() =>
      _DetailFormDescriptionSectionState();
}

class _DetailFormDescriptionSectionState
    extends State<DetailFormDescriptionSection> {
  final TextEditingController _controller = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      buildWhen: (p, n) =>
          (p.draftDetails == null) != (n.draftDetails == null) &&
          n.draftDetails != null,
      builder: (context, state) {
        if (state.draftListing == null) return const SizedBox.shrink();
        if (!_seeded) {
          _controller.text = state.draftDetails?.description ?? '';
          _seeded = true;
        }
        return StepSection(
          icon: Icons.description_outlined,
          title: l10n.formDetailDescriptionSectionTitle,
          subtitle: l10n.formDetailDescriptionSectionSubtitle,
          children: [
            FieldLabel(label: l10n.fieldLabelDescription),
            TextField(
              controller: _controller,
              maxLines: 4,
              scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
              onChanged: (v) => context.read<ListingFormBloc>().add(
                FieldChanged.description(v),
              ),
              decoration: expressDecoration(context, collapseHeight: true),
            ),
          ],
        );
      },
    );
  }
}

/// Contact + visibility section — phone / WhatsApp and the location/contact
/// visibility dropdowns, mirroring the details-page contact block.
class DetailFormContactSection extends StatefulWidget {
  const DetailFormContactSection({super.key});

  @override
  State<DetailFormContactSection> createState() =>
      _DetailFormContactSectionState();
}

class _DetailFormContactSectionState extends State<DetailFormContactSection> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  bool _seeded = false;
  String? _phoneError;
  String? _whatsappError;

  @override
  void dispose() {
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      buildWhen: (p, n) =>
          (p.draftListing == null) != (n.draftListing == null) ||
          p.draftListing?.locationVisibility !=
              n.draftListing?.locationVisibility ||
          p.draftListing?.contactNameVisibility !=
              n.draftListing?.contactNameVisibility,
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        if (!_seeded) {
          _phoneController.text = listing.phone ?? '';
          _whatsappController.text = listing.whatsapp ?? '';
          _seeded = true;
        }
        final colors = AppColors.of(context);
        return StepSection(
          icon: Icons.contact_phone_outlined,
          title: l10n.formDetailContactSectionTitle,
          subtitle: l10n.formDetailContactSectionSubtitle,
          children: [
            FieldLabel(
              label: l10n.fieldLabelPhone,
              helper: l10n.fieldLabelPhoneOrWhatsappHint,
              required: true,
            ),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: expressDecoration(context, error: _phoneError),
              onChanged: (v) {
                final result = PhoneValidator.validateAndNormalize(v, l10n);
                setState(() {
                  _phoneError = v.trim().isEmpty ? null : result.error;
                });
                context.read<ListingFormBloc>().add(
                  FieldChanged.phone(result.normalized ?? v),
                );
              },
            ),
            const FieldGap(),
            FieldLabel(label: l10n.fieldLabelWhatsapp),
            TextField(
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              decoration: expressDecoration(context, error: _whatsappError),
              onChanged: (v) {
                final result = PhoneValidator.validateAndNormalize(v, l10n);
                setState(() {
                  _whatsappError = v.trim().isEmpty ? null : result.error;
                });
                context.read<ListingFormBloc>().add(
                  FieldChanged.whatsapp(result.normalized ?? v),
                );
              },
            ),
            const FieldGap(),
            FieldLabel(label: l10n.fieldLabelLocationVisibility),
            DropdownButtonFormField<LocationVisibility>(
              initialValue: listing.locationVisibility,
              isExpanded: true,
              decoration: expressDecoration(context),
              icon: Icon(Icons.expand_more, color: colors.textMuted),
              items: LocationVisibility.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(_locationVisibilityLabel(v, l10n)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  context.read<ListingFormBloc>().add(
                    FieldChanged.locationVisibility(v),
                  );
                }
              },
            ),
            const FieldGap(),
            FieldLabel(label: l10n.fieldLabelContactNameVisibility),
            DropdownButtonFormField<ContactNameVisibility>(
              initialValue: listing.contactNameVisibility,
              isExpanded: true,
              decoration: expressDecoration(context),
              icon: Icon(Icons.expand_more, color: colors.textMuted),
              items: ContactNameVisibility.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(_contactVisibilityLabel(v, l10n)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  context.read<ListingFormBloc>().add(
                    FieldChanged.contactNameVisibility(v),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _locationVisibilityLabel(LocationVisibility v, AppLocalizations l10n) {
    switch (v) {
      case LocationVisibility.hidden:
        return l10n.locationVisibilityHidden;
      case LocationVisibility.approximate:
        return l10n.locationVisibilityApproximate;
      case LocationVisibility.exact:
        return l10n.locationVisibilityExact;
      case LocationVisibility.adminOnly:
        return l10n.locationVisibilityAdminOnly;
    }
  }

  String _contactVisibilityLabel(
    ContactNameVisibility v,
    AppLocalizations l10n,
  ) {
    switch (v) {
      case ContactNameVisibility.public:
        return l10n.contactNameVisibilityPublic;
      case ContactNameVisibility.adminOnly:
        return l10n.contactNameVisibilityAdminOnly;
    }
  }
}
