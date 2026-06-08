// lib/features/search/presentation/widgets/search_filter_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/range_slider_field.dart';
import '../../../../core/widgets/segmented_control.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../currencies/domain/repositories/currencies_repository.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../../locations/domain/entities/area.dart';
import '../../../locations/domain/entities/city_with_area_count.dart';
import '../../../locations/domain/entities/governorate_with_city_count.dart';
import '../../../locations/domain/repositories/locations_repository.dart';
import '../../domain/entities/count_filter_mode.dart';
import '../../domain/entities/filter_state.dart';

class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  final FilterState initialFilters;
  final ValueChanged<FilterState> onApply;

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  // ── Range-slider bounds (Phase 25) ──────────────────────────────────────
  // Price slider domain: 0 → [_kPriceMax]. When `end` sits at the cap we treat
  // it as "no upper bound" (null priceMax) so the slider can express open-ended
  // ranges. The selected currency only labels the values — conversion to
  // USD/SYP happens in the datasource (R-75).
  static const double _kPriceMax = 1000000;
  static const double _kAreaMax = 1000;
  static const int _kBedsBathsMax = 5;

  // Local mutable state mirroring FilterState fields
  ListingPurpose? _purpose;
  PropertyType? _propertyType;
  String? _governorateId;
  String? _cityId;
  String? _areaId;
  RangeValues _priceRange = const RangeValues(0, _kPriceMax);
  String? _priceCurrency;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int? _rooms;
  CountFilterMode _roomsMode = CountFilterMode.exactly;
  int? _bathrooms;
  CountFilterMode _bathroomsMode = CountFilterMode.exactly;
  RangeValues _areaRange = const RangeValues(0, _kAreaMax);

  // Owner-vs-agency lister filter: null = all, false = owner, true = agency.
  bool? _isAgency;

  // Location data
  List<GovernorateWithCityCount> _governorates = [];
  List<CityWithAreaCount> _cities = [];
  List<Area> _areas = [];
  bool _loadingGovernorates = false;

  // Currency data
  List<Currency> _currencies = [];

  @override
  void initState() {
    super.initState();
    // Initialize local state from initialFilters
    _purpose = widget.initialFilters.purpose;
    _propertyType = widget.initialFilters.propertyType;
    _governorateId = widget.initialFilters.governorateId;
    _cityId = widget.initialFilters.cityId;
    _areaId = widget.initialFilters.areaId;
    _priceRange = _safeRange(
      widget.initialFilters.priceMin,
      widget.initialFilters.priceMax,
      _kPriceMax,
    );
    _priceCurrency = widget.initialFilters.priceCurrency;
    _rooms = widget.initialFilters.rooms;
    _roomsMode = widget.initialFilters.roomsMode;
    _bathrooms = widget.initialFilters.bathrooms;
    _bathroomsMode = widget.initialFilters.bathroomsMode;
    _areaRange = _safeRange(
      widget.initialFilters.areaSizeMin,
      widget.initialFilters.areaSizeMax,
      _kAreaMax,
    );
    _isAgency = widget.initialFilters.isAgency;

    _loadGovernorates();
    _loadCurrencies();
  }

  Future<void> _loadGovernorates() async {
    setState(() => _loadingGovernorates = true);
    try {
      final result = await getIt<LocationsRepository>().listGovernorates(
        includeInactive: false,
      );
      if (mounted) {
        setState(() {
          _governorates = result;
          _loadingGovernorates = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingGovernorates = false);
      }
    }
  }

  Future<void> _loadCurrencies() async {
    try {
      final result = await getIt<CurrenciesRepository>().listCurrencies(
        activeOnly: true,
      );
      if (mounted) {
        setState(() => _currencies = result);
      }
    } catch (_) {
      // Silently swallow — currency selector will be empty
    }
  }

  Future<void> _onGovernorateChanged(String? id) async {
    setState(() {
      _governorateId = id;
      _cityId = null;
      _areaId = null;
      _cities = [];
      _areas = [];
    });
    if (id != null) {
      try {
        final cities = await getIt<LocationsRepository>()
            .listCitiesForGovernorate(id, includeInactive: false);
        if (mounted) {
          setState(() => _cities = cities);
        }
      } catch (_) {
        // Silently swallow
      }
    }
  }

  Future<void> _onCityChanged(String? id) async {
    setState(() {
      _cityId = id;
      _areaId = null;
      _areas = [];
    });
    if (id != null) {
      try {
        final areas = await getIt<LocationsRepository>().listAreasForCity(
          id,
          includeInactive: false,
        );
        if (mounted) {
          setState(() => _areas = areas);
        }
      } catch (_) {
        // Silently swallow
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHandle(),
                _buildTitle(context),
                const SizedBox(height: 16),
                _buildPurposeSection(context),
                const SizedBox(height: 16),
                _buildPropertyTypeSection(context),
                const SizedBox(height: 16),
                _buildListerTypeSection(context),
                const SizedBox(height: 16),
                _buildLocationSection(context),
                const SizedBox(height: 16),
                _buildPriceRangeSection(context),
                const SizedBox(height: 16),
                _buildRoomsSection(context),
                const SizedBox(height: 16),
                _buildBathroomsSection(context),
                const SizedBox(height: 16),
                _buildAreaSizeSection(context),
                const SizedBox(height: 24),
                _buildActionRow(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(
              AppRadii.pill,
            ), // drag-handle bar — fully rounded
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.search_filter_sheet_title,
      style: Theme.of(context).textTheme.titleMedium,
      textAlign: TextAlign.start,
    );
  }

  Widget _buildPurposeSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.search_filter_purpose_label,
          style: Theme.of(context).textTheme.labelLarge,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ListingPurpose.values.map((p) {
            return ChoiceChip(
              label: Text(_localizedPurpose(p, l10n)),
              selected: _purpose == p,
              onSelected: (v) => setState(() => _purpose = v ? p : null),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPropertyTypeSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.search_filter_property_type_label,
          style: Theme.of(context).textTheme.labelLarge,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: PropertyType.values.map((t) {
            return ChoiceChip(
              label: Text(_localizedPropertyType(t, l10n)),
              selected: _propertyType == t,
              onSelected: (v) => setState(() => _propertyType = v ? t : null),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Owner-vs-agency lister filter. A three-way segmented toggle bound to
  /// [_isAgency] (null = all · false = owner · true = agency). Reuses the
  /// Phase-25 [AppSegmentedControl] idiom (same control the beds/baths
  /// exactly/at-least toggle uses).
  Widget _buildListerTypeSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.search_filter_lister_type_label,
          style: Theme.of(context).textTheme.labelLarge,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        AppSegmentedControl<bool?>(
          value: _isAgency,
          onChanged: (v) => setState(() => _isAgency = v),
          segments: [
            AppSegmentedSegment<bool?>(
              icon: Icons.apps,
              label: l10n.search_filter_lister_type_all,
              value: null,
            ),
            AppSegmentedSegment<bool?>(
              icon: Icons.person_outline,
              label: l10n.search_filter_lister_type_owner,
              value: false,
            ),
            AppSegmentedSegment<bool?>(
              icon: Icons.business_outlined,
              label: l10n.search_filter_lister_type_agency,
              value: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.search_filter_location_label,
          style: Theme.of(context).textTheme.labelLarge,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        // Governorate dropdown
        DropdownButton<String?>(
          isExpanded: true,
          value: _governorateId,
          hint: Text(l10n.search_filter_governorate_hint),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.search_filter_governorate_hint),
            ),
            ..._governorates.map(
              (g) => DropdownMenuItem<String?>(
                value: g.governorate.id,
                child: Text(
                  g.governorate.displayName['ar'] ??
                      g.governorate.displayName['en'] ??
                      g.governorate.key,
                ),
              ),
            ),
          ],
          onChanged: _loadingGovernorates ? null : _onGovernorateChanged,
        ),
        const SizedBox(height: 8),
        // City dropdown
        DropdownButton<String?>(
          isExpanded: true,
          value: _cityId,
          hint: Text(l10n.search_filter_city_hint),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.search_filter_city_hint),
            ),
            ..._cities.map(
              (c) => DropdownMenuItem<String?>(
                value: c.city.id,
                child: Text(
                  c.city.displayName['ar'] ??
                      c.city.displayName['en'] ??
                      c.city.key,
                ),
              ),
            ),
          ],
          onChanged: _governorateId == null ? null : _onCityChanged,
        ),
        const SizedBox(height: 8),
        // Area dropdown
        DropdownButton<String?>(
          isExpanded: true,
          value: _areaId,
          hint: Text(l10n.search_filter_area_hint),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.search_filter_area_hint),
            ),
            ..._areas.map(
              (a) => DropdownMenuItem<String?>(
                value: a.id,
                child: Text(
                  a.displayName['ar'] ?? a.displayName['en'] ?? a.key,
                ),
              ),
            ),
          ],
          onChanged: _cityId == null
              ? null
              : (id) => setState(() {
                  _areaId = id;
                }),
        ),
      ],
    );
  }

  Widget _buildPriceRangeSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.search_filter_price_range_label,
          style: Theme.of(context).textTheme.labelLarge,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        // Currency selector
        DropdownButton<String?>(
          isExpanded: true,
          value: _priceCurrency,
          hint: Text(l10n.search_filter_price_currency_label),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.search_filter_price_currency_label),
            ),
            ..._currencies.map(
              (c) => DropdownMenuItem<String?>(
                value: c.code,
                child: Text('${c.code} ${c.symbol}'),
              ),
            ),
          ],
          onChanged: (code) => setState(() => _priceCurrency = code),
        ),
        const SizedBox(height: 8),
        RangeSliderField(
          label: l10n.search_filter_price_range_label,
          min: 0,
          max: _kPriceMax,
          divisions: 100,
          values: _priceRange,
          formatValue: (v) => _formatPrice(v, atCap: v >= _kPriceMax),
          onChanged: (range) => setState(() => _priceRange = range),
        ),
      ],
    );
  }

  /// Builds a valid [RangeValues] from optional min/max bounds, clamped into
  /// [0, cap] and normalized so start ≤ end (tolerates malformed saved data).
  static RangeValues _safeRange(double? min, double? max, double cap) {
    var start = (min ?? 0).clamp(0.0, cap);
    var end = (max ?? cap).clamp(0.0, cap);
    if (start > end) {
      final tmp = start;
      start = end;
      end = tmp;
    }
    return RangeValues(start, end);
  }

  /// Compact, locale-aware money label. When [atCap] the upper-bound reads as
  /// "no max" (the slider's max position expresses an open-ended range).
  String _formatPrice(double value, {bool atCap = false}) {
    final l10n = AppLocalizations.of(context)!;
    if (atCap) return l10n.search_filter_range_no_max;
    final locale = Localizations.localeOf(context).toString();
    return NumberFormat.compact(locale: locale).format(value.round());
  }

  Widget _buildRoomsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _buildCountSection(
      context,
      label: l10n.search_filter_rooms_label,
      value: _rooms,
      mode: _roomsMode,
      onValueChanged: (v) => setState(() => _rooms = v),
      onModeChanged: (m) => setState(() => _roomsMode = m),
    );
  }

  Widget _buildBathroomsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _buildCountSection(
      context,
      label: l10n.search_filter_bathrooms_label,
      value: _bathrooms,
      mode: _bathroomsMode,
      onValueChanged: (v) => setState(() => _bathrooms = v),
      onModeChanged: (m) => setState(() => _bathroomsMode = m),
    );
  }

  /// Shared beds/baths selector: a row of count chips (Any · 1 · 2 · 3 · 4 ·
  /// 5+) plus an exactly/at-least mode toggle (shown only when a count is set).
  Widget _buildCountSection(
    BuildContext context, {
    required String label,
    required int? value,
    required CountFilterMode mode,
    required ValueChanged<int?> onValueChanged,
    required ValueChanged<CountFilterMode> onModeChanged,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();
    final numberFmt = NumberFormat.decimalPattern(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: styles.labelLarge, textAlign: TextAlign.start),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: Text(l10n.search_filter_count_any),
              selected: value == null,
              onSelected: (_) => onValueChanged(null),
            ),
            for (var n = 1; n <= _kBedsBathsMax; n++)
              ChoiceChip(
                label: Text(
                  n == _kBedsBathsMax
                      ? '${numberFmt.format(n)}+'
                      : numberFmt.format(n),
                ),
                selected: value == n,
                onSelected: (_) => onValueChanged(n),
              ),
          ],
        ),
        if (value != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppSegmentedControl<CountFilterMode>(
            value: mode,
            onChanged: onModeChanged,
            segments: [
              AppSegmentedSegment(
                icon: Icons.drag_handle,
                label: l10n.search_filter_rooms_exactly,
                value: CountFilterMode.exactly,
              ),
              AppSegmentedSegment(
                icon: Icons.add,
                label: l10n.search_filter_rooms_at_least,
                value: CountFilterMode.atLeast,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAreaSizeSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.search_filter_area_size_label,
          style: Theme.of(context).textTheme.labelLarge,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        RangeSliderField(
          label: l10n.search_filter_area_size_label,
          min: 0,
          max: _kAreaMax,
          divisions: 100,
          values: _areaRange,
          formatValue: (v) => v >= _kAreaMax
              ? l10n.search_filter_range_no_max
              : l10n.search_filter_area_size_value(
                  NumberFormat.decimalPattern(
                    Localizations.localeOf(context).toString(),
                  ).format(v.round()),
                ),
          onChanged: (range) => setState(() => _areaRange = range),
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => setState(() {
            _purpose = null;
            _propertyType = null;
            _governorateId = null;
            _cityId = null;
            _areaId = null;
            _cities = [];
            _areas = [];
            _priceRange = const RangeValues(0, _kPriceMax);
            _priceCurrency = null;
            _rooms = null;
            _roomsMode = CountFilterMode.exactly;
            _bathrooms = null;
            _bathroomsMode = CountFilterMode.exactly;
            _areaRange = const RangeValues(0, _kAreaMax);
            _isAgency = null;
          }),
          child: Text(l10n.search_filter_reset),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            // Slider sentinels: a `start` of 0 ⇒ no minimum; an `end` at the
            // cap ⇒ no maximum (open-ended). Either way the bound is null so
            // the RPC treats that direction as unfiltered.
            final priceMin = _priceRange.start > 0 ? _priceRange.start : null;
            final priceMax = _priceRange.end < _kPriceMax
                ? _priceRange.end
                : null;
            final areaMin = _areaRange.start > 0 ? _areaRange.start : null;
            final areaMax = _areaRange.end < _kAreaMax ? _areaRange.end : null;
            final newFilters = FilterState(
              purpose: _purpose,
              propertyType: _propertyType,
              governorateId: _governorateId,
              cityId: _cityId,
              areaId: _areaId,
              priceMin: priceMin,
              priceMax: priceMax,
              // Only carry a currency when a price bound is active — the
              // datasource needs it for USD/SYP conversion (R-75).
              priceCurrency: (priceMin != null || priceMax != null)
                  ? _priceCurrency
                  : null,
              rooms: _rooms,
              roomsMode: _roomsMode,
              bathrooms: _bathrooms,
              bathroomsMode: _bathroomsMode,
              areaSizeMin: areaMin,
              areaSizeMax: areaMax,
              isAgency: _isAgency,
            );
            widget.onApply(newFilters);
            Navigator.of(context).pop();
          },
          child: Text(l10n.search_filter_apply),
        ),
      ],
    );
  }

  String _localizedPurpose(ListingPurpose p, AppLocalizations l10n) {
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

  String _localizedPropertyType(PropertyType t, AppLocalizations l10n) {
    switch (t) {
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
