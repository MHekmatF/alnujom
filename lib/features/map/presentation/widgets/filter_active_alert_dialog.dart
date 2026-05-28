// lib/features/map/presentation/widgets/filter_active_alert_dialog.dart
//
// Phase 15 Sub-Phase E (T050) — one-shot AlertDialog surfaced when the
// user enters the map from search with active filters per
// contracts/phase15-map-page-composition.md §Filter-active alert
// (FR-007a, SC-013, US6).
//
// The dialog summarizes the active filter dimensions as a `Wrap` of
// `Chip`s (purpose / property type / governorate / city / area / price /
// rooms / bathrooms / area size / keyword query). Tapping
//   • "Reset filters" → dispatches [FilterResetRequested] (full unfiltered
//     dataset re-fetch) and pops the dialog.
//   • "Keep filters"  → dispatches [FilterAlertDismissed] (no re-fetch) and
//     pops the dialog.
//
// The show-once gating lives in the page's `_alertShown` flag so this
// widget can stay stateless.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../../search/domain/entities/count_filter_mode.dart';
import '../../../search/domain/entities/filter_state.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';

class FilterActiveAlertDialog extends StatelessWidget {
  const FilterActiveAlertDialog({super.key, required this.filterState});

  final FilterState filterState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chips = _buildChips(l10n, filterState);

    return AlertDialog(
      title: Text(l10n.map_filter_alert_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.map_filter_alert_body_prefix),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: chips
                .map((label) => Chip(label: Text(label)))
                .toList(growable: false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            context.read<MapBloc>().add(const FilterAlertDismissed());
            Navigator.of(context).pop();
          },
          child: Text(l10n.map_filter_alert_action_keep),
        ),
        TextButton(
          onPressed: () {
            context.read<MapBloc>().add(const FilterResetRequested());
            Navigator.of(context).pop();
          },
          child: Text(l10n.map_filter_alert_action_reset),
        ),
      ],
    );
  }

  // ─── Chip composition ───────────────────────────────────────────────────────
  // Reuses the existing search_filter_* + property type / purpose labels for
  // a consistent vocabulary with the search filter sheet.

  List<String> _buildChips(AppLocalizations l10n, FilterState f) {
    final out = <String>[];
    if (f.purpose != null) {
      out.add(
        _labelled(
          l10n.search_filter_purpose_label,
          _purposeLabel(l10n, f.purpose!),
        ),
      );
    }
    if (f.propertyType != null) {
      out.add(
        _labelled(
          l10n.search_filter_property_type_label,
          _propertyTypeLabel(l10n, f.propertyType!),
        ),
      );
    }
    // Location filter: collapse {governorate, city, area} into a single
    // chip showing the most specific level set. Raw IDs (UUIDs / slugs) would
    // be meaningless to the user; resolving them to display names would
    // require an extra lookup that this short-lived alert dialog isn't worth.
    // The search-results page (one back-press away) renders the resolved name.
    final locationLabel = f.areaId != null
        ? l10n.search_filter_area_hint
        : f.cityId != null
        ? l10n.search_filter_city_hint
        : f.governorateId != null
        ? l10n.search_filter_governorate_hint
        : null;
    if (locationLabel != null) {
      out.add(locationLabel);
    }
    if (f.priceMin != null || f.priceMax != null) {
      out.add(_priceRangeLabel(l10n, f));
    }
    if (f.rooms != null) {
      out.add(
        _labelled(
          l10n.search_filter_rooms_label,
          _countLabel(l10n, f.rooms!, f.roomsMode),
        ),
      );
    }
    if (f.bathrooms != null) {
      out.add(
        _labelled(
          l10n.search_filter_bathrooms_label,
          _countLabel(l10n, f.bathrooms!, f.bathroomsMode),
        ),
      );
    }
    if (f.areaSizeMin != null || f.areaSizeMax != null) {
      out.add(_areaSizeLabel(l10n, f));
    }
    if (f.query != null && f.query!.isNotEmpty) {
      out.add(_labelled(l10n.search_placeholder, f.query!));
    }
    return out;
  }

  String _labelled(String label, String value) => '$label: $value';

  String _countLabel(AppLocalizations l10n, int n, CountFilterMode mode) {
    final suffix = mode == CountFilterMode.exactly
        ? l10n.search_filter_rooms_exactly
        : l10n.search_filter_rooms_at_least;
    return '$n $suffix';
  }

  String _priceRangeLabel(AppLocalizations l10n, FilterState f) {
    final min = f.priceMin?.toString() ?? '*';
    final max = f.priceMax?.toString() ?? '*';
    final currency = f.priceCurrency ?? '';
    final body = currency.isEmpty ? '$min – $max' : '$min – $max $currency';
    return _labelled(l10n.search_filter_price_range_label, body);
  }

  String _areaSizeLabel(AppLocalizations l10n, FilterState f) {
    final min = f.areaSizeMin?.toString() ?? '*';
    final max = f.areaSizeMax?.toString() ?? '*';
    return _labelled(l10n.search_filter_area_size_label, '$min – $max');
  }

  String _propertyTypeLabel(AppLocalizations l10n, PropertyType type) {
    switch (type) {
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

  String _purposeLabel(AppLocalizations l10n, ListingPurpose purpose) {
    switch (purpose) {
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
}
