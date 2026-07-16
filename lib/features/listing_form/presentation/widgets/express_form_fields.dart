import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
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
import 'step_section.dart';

/// Phase 32 — building blocks for the "Express" (سريع) create form: the Al
/// Nujom Design System add-listing aesthetic — flat **big rounded fields** with
/// a label above, segmented purpose pills, and two-up rows. Visually distinct
/// from the detail-view's bordered section cards. Every control dispatches the
/// EXISTING [FieldChanged] events on the EXISTING [ListingFormBloc] (no new
/// events, no bloc edits), so it shares the same validation + submit path.

/// A labelled "big field" shell — the DS `.field-big` look (tall, rounded,
/// filled) with the label sitting above it.
class ExpressField extends StatelessWidget {
  const ExpressField({
    required this.label,
    required this.child,
    this.required = false,
    this.helper,
    super.key,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reuse the shared FieldLabel (label + the required chip + optional
        // helper) so the required badge matches the rest of the form.
        FieldLabel(label: label, required: required, helper: helper),
        child,
      ],
    );
  }
}

/// Minimum height for the DS `.field-big` shell (~58 in the design). Driven
/// through [InputDecoration.constraints] so single-line fields read tall and
/// soft regardless of font metrics.
const double _kExpressFieldMinHeight = 58;

/// Minimum height for a segmented purpose pill (~52 in the design).
const double _kPurposePillHeight = 52;

/// Shared big-field decoration (tall, filled, rounded) so the express fields
/// read taller + softer than the default inputs — the DS `.field-big` look:
/// `surfaceVariant` fill, 1.5px `outline` border, md radius, `primary` on focus.
///
/// [suffix] renders a unit token (e.g. م²) pinned at the end in muted bold; pass
/// [collapseHeight] for multi-line fields so the min-height clamp is dropped.
InputDecoration expressDecoration(
  BuildContext context, {
  String? hint,
  String? error,
  Widget? suffix,
  bool collapseHeight = false,
}) {
  final colors = AppColors.of(context);
  final styles = AppTextStyles.of(context);
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: appRadius(AppRadii.md),
    borderSide: BorderSide(color: color, width: 1.5),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: styles.bodyLarge.copyWith(color: colors.textMuted),
    errorText: error,
    filled: true,
    fillColor: colors.surfaceVariant,
    suffixIcon: suffix,
    constraints: collapseHeight
        ? null
        : const BoxConstraints(minHeight: _kExpressFieldMinHeight),
    contentPadding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    enabledBorder: border(colors.outline),
    border: border(colors.outline),
    focusedBorder: border(colors.primary),
    errorBorder: border(colors.error),
    focusedErrorBorder: border(colors.error),
  );
}

/// A unit suffix (e.g. م²) for the price/area big fields — muted + bold, pinned
/// at the field's end edge.
Widget _expressUnitSuffix(BuildContext context, String unit) {
  final colors = AppColors.of(context);
  final styles = AppTextStyles.of(context);
  return Padding(
    padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
    child: Text(
      unit,
      style: styles.labelLarge.copyWith(color: colors.textMuted),
    ),
  );
}

/// Title — a single big text field.
class ExpressTitleField extends StatefulWidget {
  const ExpressTitleField({super.key});
  @override
  State<ExpressTitleField> createState() => _ExpressTitleFieldState();
}

class _ExpressTitleFieldState extends State<ExpressTitleField> {
  final _controller = TextEditingController();
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
        return ExpressField(
          label: l10n.fieldLabelTitle,
          required: true,
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.next,
            decoration: expressDecoration(context, hint: l10n.fieldLabelTitle),
            onChanged: (v) =>
                context.read<ListingFormBloc>().add(FieldChanged.title(v)),
          ),
        );
      },
    );
  }
}

/// Purpose as segmented pills (للبيع / للإيجار / …) + property type dropdown.
class ExpressClassification extends StatelessWidget {
  const ExpressClassification({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      buildWhen: (p, n) =>
          p.draftListing?.purpose != n.draftListing?.purpose ||
          p.draftListing?.propertyType != n.draftListing?.propertyType,
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExpressField(
              label: l10n.fieldLabelPurpose,
              required: true,
              // 2-up grid of equal pills (2 rows of 2 for the four purposes) —
              // compact + matches the DS segmented look.
              child: Column(
                children: [
                  for (var i = 0; i < ListingPurpose.values.length; i += 2) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _PurposePill(
                            label: listingPurposeLabel(
                              ListingPurpose.values[i],
                              l10n,
                            ),
                            selected:
                                listing.purpose == ListingPurpose.values[i],
                            onTap: () => context.read<ListingFormBloc>().add(
                              FieldChanged.purpose(ListingPurpose.values[i]),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (i + 1 < ListingPurpose.values.length)
                          Expanded(
                            child: _PurposePill(
                              label: listingPurposeLabel(
                                ListingPurpose.values[i + 1],
                                l10n,
                              ),
                              selected:
                                  listing.purpose ==
                                  ListingPurpose.values[i + 1],
                              onTap: () => context.read<ListingFormBloc>().add(
                                FieldChanged.purpose(
                                  ListingPurpose.values[i + 1],
                                ),
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ExpressField(
              label: l10n.fieldLabelPropertyType,
              required: true,
              child: DropdownButtonFormField<PropertyType>(
                initialValue: listing.propertyType,
                isExpanded: true,
                decoration: expressDecoration(context),
                icon: Icon(Icons.expand_more, color: colors.textMuted),
                style: styles.bodyLarge.copyWith(color: colors.onSurface),
                items: [
                  for (final t in PropertyType.values)
                    DropdownMenuItem(
                      value: t,
                      child: Text(propertyTypeLabel(t, l10n)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    context.read<ListingFormBloc>().add(
                      FieldChanged.propertyType(v),
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PurposePill extends StatelessWidget {
  const _PurposePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? colors.primary : colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.md),
        child: InkWell(
          borderRadius: appRadius(AppRadii.md),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.xxxl,
              minHeight: _kPurposePillHeight,
            ),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: appRadius(AppRadii.md),
              // Selected pills lose the border (filled primary); idle pills carry
              // the 1.5px outline of the DS segmented control.
              border: selected
                  ? null
                  : Border.all(color: colors.outline, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: styles.labelLarge.copyWith(
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Price (amount + currency) and area, laid two-up.
class ExpressPriceArea extends StatefulWidget {
  const ExpressPriceArea({super.key});
  @override
  State<ExpressPriceArea> createState() => _ExpressPriceAreaState();
}

class _ExpressPriceAreaState extends State<ExpressPriceArea> {
  final _amount = TextEditingController();
  final _area = TextEditingController();
  Future<List<Currency>>? _currencies;
  bool _seeded = false;
  bool _currencyAuto = false;
  String? _amountError;
  String? _areaError;

  @override
  void initState() {
    super.initState();
    _currencies = getIt<ListCurrencies>().call(activeOnly: true);
  }

  @override
  void dispose() {
    _amount.dispose();
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        final price = state.draftPrice;
        if (!_seeded) {
          _amount.text = price?.amount.toString() ?? '';
          _area.text =
              listing.areaSize?.toString().replaceAll(RegExp(r'\.0$'), '') ?? '';
          _seeded = true;
        }
        return FutureBuilder<List<Currency>>(
          future: _currencies,
          builder: (context, snap) {
            final currencies = snap.data ?? const <Currency>[];
            final currencyCode =
                price?.currencyCode ??
                (currencies.isNotEmpty ? currencies.first.code : null);
            if (currencies.isNotEmpty && !_currencyAuto && price == null) {
              _currencyAuto = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                context.read<ListingFormBloc>().add(
                  FieldChanged.priceCurrencyCode(currencies.first.code),
                );
              });
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ExpressField(
                    label: l10n.fieldLabelPrice,
                    required: true,
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: expressDecoration(
                        context,
                        suffix: currencyCode == null
                            ? null
                            : _expressUnitSuffix(context, currencyCode),
                        error: _amountError,
                      ),
                      onChanged: (v) {
                        final parsed = Decimal.tryParse(v);
                        // Inline pre-submit feedback (display-only): reuse the
                        // same PriceValidator the Detail/Classic flows use. The
                        // dispatched FieldChanged event is unchanged.
                        if (currencies.isNotEmpty) {
                          final activeCurrency = currencies.firstWhere(
                            (c) => c.code == currencyCode,
                            orElse: () => currencies.first,
                          );
                          setState(() {
                            _amountError = PriceValidator.validate(
                              parsed,
                              activeCurrency,
                              l10n,
                            );
                          });
                        }
                        if (parsed != null) {
                          context.read<ListingFormBloc>().add(
                            FieldChanged.priceAmount(parsed),
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ExpressField(
                    label: l10n.fieldLabelAreaSize,
                    required: true,
                    child: TextField(
                      controller: _area,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: expressDecoration(
                        context,
                        suffix: _expressUnitSuffix(context, l10n.spec_area_unit),
                        error: _areaError,
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        // Inline pre-submit feedback (display-only): reuse the
                        // same AreaSizeValidator as the Detail/Classic flows.
                        setState(() {
                          _areaError = AreaSizeValidator.validate(parsed, l10n);
                        });
                        context.read<ListingFormBloc>().add(
                          FieldChanged.areaSize(parsed),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Location picker + a big address field.
class ExpressLocation extends StatefulWidget {
  const ExpressLocation({super.key});
  @override
  State<ExpressLocation> createState() => _ExpressLocationState();
}

class _ExpressLocationState extends State<ExpressLocation> {
  final _address = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _address.dispose();
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
          _address.text = listing.addressText ?? '';
          _seeded = true;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              onChanged: (sel) {
                final bloc = context.read<ListingFormBloc>();
                bloc.add(FieldChanged.governorateId(sel?.governorateId));
                bloc.add(FieldChanged.cityId(sel?.cityId));
                bloc.add(FieldChanged.areaId(sel?.areaId));
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            ExpressField(
              label: l10n.fieldLabelAddressText,
              required: true,
              child: TextField(
                controller: _address,
                maxLines: 2,
                decoration: expressDecoration(context, collapseHeight: true),
                onChanged: (v) => context.read<ListingFormBloc>().add(
                  FieldChanged.addressText(v),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Rooms + bathrooms two-up (residential only) and the contact phone.
class ExpressFactsContact extends StatefulWidget {
  const ExpressFactsContact({super.key});
  @override
  State<ExpressFactsContact> createState() => _ExpressFactsContactState();
}

class _ExpressFactsContactState extends State<ExpressFactsContact> {
  final _rooms = TextEditingController();
  final _baths = TextEditingController();
  final _phone = TextEditingController();
  bool _seeded = false;
  String? _phoneError;

  @override
  void dispose() {
    _rooms.dispose();
    _baths.dispose();
    _phone.dispose();
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
          _rooms.text = listing.rooms?.toString() ?? '';
          _baths.text = listing.bathrooms?.toString() ?? '';
          _phone.text = listing.phone ?? '';
          _seeded = true;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (listing.propertyType.isResidential) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ExpressField(
                      label: l10n.fieldLabelRooms,
                      required: true,
                      child: TextField(
                        controller: _rooms,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: expressDecoration(context),
                        onChanged: (v) => context.read<ListingFormBloc>().add(
                          FieldChanged.rooms(int.tryParse(v)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ExpressField(
                      label: l10n.fieldLabelBathrooms,
                      required: true,
                      child: TextField(
                        controller: _baths,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: expressDecoration(context),
                        onChanged: (v) => context.read<ListingFormBloc>().add(
                          FieldChanged.bathrooms(int.tryParse(v)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            ExpressField(
              label: l10n.fieldLabelPhone,
              required: true,
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: expressDecoration(
                  context,
                  hint: l10n.fieldLabelPhoneOrWhatsappHint,
                  error: _phoneError,
                ),
                onChanged: (v) {
                  // Inline pre-submit feedback (display-only): reuse the same
                  // PhoneValidator the Detail/Classic flows use. The dispatched
                  // FieldChanged.phone(v) event is unchanged (raw value).
                  final result = PhoneValidator.validateAndNormalize(v, l10n);
                  setState(() {
                    _phoneError = v.trim().isEmpty ? null : result.error;
                  });
                  context.read<ListingFormBloc>().add(
                    FieldChanged.phone(v),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
