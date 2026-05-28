// lib/features/search/presentation/widgets/search_filter_sheet.dart
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
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
import 'price_range_input.dart';

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
  // Local mutable state mirroring FilterState fields
  ListingPurpose? _purpose;
  PropertyType? _propertyType;
  String? _governorateId;
  String? _cityId;
  String? _areaId;
  final TextEditingController _priceMinController = TextEditingController();
  final TextEditingController _priceMaxController = TextEditingController();
  String? _priceCurrency;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int? _rooms;
  CountFilterMode _roomsMode = CountFilterMode.exactly;
  int? _bathrooms;
  CountFilterMode _bathroomsMode = CountFilterMode.exactly;
  final TextEditingController _areaSizeMinController = TextEditingController();
  final TextEditingController _areaSizeMaxController = TextEditingController();

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
    if (widget.initialFilters.priceMin != null) {
      _priceMinController.text = widget.initialFilters.priceMin!.toString();
    }
    if (widget.initialFilters.priceMax != null) {
      _priceMaxController.text = widget.initialFilters.priceMax!.toString();
    }
    _priceCurrency = widget.initialFilters.priceCurrency;
    _rooms = widget.initialFilters.rooms;
    _roomsMode = widget.initialFilters.roomsMode;
    _bathrooms = widget.initialFilters.bathrooms;
    _bathroomsMode = widget.initialFilters.bathroomsMode;
    if (widget.initialFilters.areaSizeMin != null) {
      _areaSizeMinController.text = widget.initialFilters.areaSizeMin!
          .toString();
    }
    if (widget.initialFilters.areaSizeMax != null) {
      _areaSizeMaxController.text = widget.initialFilters.areaSizeMax!
          .toString();
    }

    _loadGovernorates();
    _loadCurrencies();
  }

  @override
  void dispose() {
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _areaSizeMinController.dispose();
    _areaSizeMaxController.dispose();
    super.dispose();
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
        PriceRangeInput(
          minController: _priceMinController,
          maxController: _priceMaxController,
          formKey: _formKey,
        ),
      ],
    );
  }

  Widget _buildRoomsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.search_filter_rooms_label,
          style: Theme.of(context).textTheme.labelLarge,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        SegmentedButton<CountFilterMode>(
          segments: [
            ButtonSegment(
              value: CountFilterMode.exactly,
              label: Text(l10n.search_filter_rooms_exactly),
            ),
            ButtonSegment(
              value: CountFilterMode.atLeast,
              label: Text(l10n.search_filter_rooms_at_least),
            ),
          ],
          selected: {_roomsMode},
          onSelectionChanged: (s) => setState(() => _roomsMode = s.first),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _rooms != null && _rooms! > 0
                  ? () => setState(() {
                      if (_rooms! <= 1) {
                        _rooms = null;
                      } else {
                        _rooms = _rooms! - 1;
                      }
                    })
                  : null,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Text(
                _rooms?.toString() ?? '—',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _rooms = (_rooms ?? 0) + 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBathroomsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.search_filter_bathrooms_label,
          style: Theme.of(context).textTheme.labelLarge,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        SegmentedButton<CountFilterMode>(
          segments: [
            ButtonSegment(
              value: CountFilterMode.exactly,
              label: Text(l10n.search_filter_rooms_exactly),
            ),
            ButtonSegment(
              value: CountFilterMode.atLeast,
              label: Text(l10n.search_filter_rooms_at_least),
            ),
          ],
          selected: {_bathroomsMode},
          onSelectionChanged: (s) => setState(() => _bathroomsMode = s.first),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _bathrooms != null && _bathrooms! > 0
                  ? () => setState(() {
                      if (_bathrooms! <= 1) {
                        _bathrooms = null;
                      } else {
                        _bathrooms = _bathrooms! - 1;
                      }
                    })
                  : null,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Text(
                _bathrooms?.toString() ?? '—',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () =>
                  setState(() => _bathrooms = (_bathrooms ?? 0) + 1),
            ),
          ],
        ),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                child: TextFormField(
                  controller: _areaSizeMinController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.search_filter_price_min_hint,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
                child: TextFormField(
                  controller: _areaSizeMaxController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.search_filter_price_max_hint,
                  ),
                ),
              ),
            ),
          ],
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
            _priceMinController.clear();
            _priceMaxController.clear();
            _priceCurrency = null;
            _rooms = null;
            _roomsMode = CountFilterMode.exactly;
            _bathrooms = null;
            _bathroomsMode = CountFilterMode.exactly;
            _areaSizeMinController.clear();
            _areaSizeMaxController.clear();
          }),
          child: Text(l10n.search_filter_reset),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final newFilters = FilterState(
              purpose: _purpose,
              propertyType: _propertyType,
              governorateId: _governorateId,
              cityId: _cityId,
              areaId: _areaId,
              priceMin: _priceMinController.text.isNotEmpty
                  ? double.tryParse(_priceMinController.text)
                  : null,
              priceMax: _priceMaxController.text.isNotEmpty
                  ? double.tryParse(_priceMaxController.text)
                  : null,
              priceCurrency: _priceCurrency,
              rooms: _rooms,
              roomsMode: _roomsMode,
              bathrooms: _bathrooms,
              bathroomsMode: _bathroomsMode,
              areaSizeMin: _areaSizeMinController.text.isNotEmpty
                  ? double.tryParse(_areaSizeMinController.text)
                  : null,
              areaSizeMax: _areaSizeMaxController.text.isNotEmpty
                  ? double.tryParse(_areaSizeMaxController.text)
                  : null,
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
