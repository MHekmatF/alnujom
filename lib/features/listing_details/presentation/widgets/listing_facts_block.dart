import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/widgets/facts_grid.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../../listing_form/domain/entities/listing.dart';

/// Premium uplift v2 — the listing-detail key-facts block.
///
/// Maps the source listing's beds / baths / area / floor / type onto a
/// [FactsGrid] of soft tiles placed right under the title + price. Renders only
/// the facts that are present (land has no rooms/baths, etc.), and collapses to
/// nothing when none apply. Numbers render in the active locale's numerals.
class ListingFactsBlock extends StatelessWidget {
  const ListingFactsBlock({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    final items = <FactItem>[
      if (listing.rooms != null)
        FactItem(
          icon: LucideIcons.bed,
          value: formatLocalizedNumber(listing.rooms!, locale),
          label: l10n.spec_rooms_label,
        ),
      if (listing.bathrooms != null)
        FactItem(
          icon: LucideIcons.bath,
          value: formatLocalizedNumber(listing.bathrooms!, locale),
          label: l10n.spec_baths_label,
        ),
      if (listing.areaSize != null)
        FactItem(
          icon: LucideIcons.ruler,
          value: '${_formatArea(locale, listing.areaSize!)} ${l10n.spec_area_unit}',
          label: l10n.spec_area_label,
        ),
      if (listing.floor != null)
        FactItem(
          icon: LucideIcons.layers,
          value: formatLocalizedNumber(listing.floor!, locale),
          label: l10n.spec_floor_label,
        ),
      FactItem(
        icon: LucideIcons.house,
        value: _propertyTypeLabel(l10n, listing.propertyType),
        label: l10n.listing_details_facts_type_label,
      ),
    ];

    return FactsGrid(items: items);
  }

  static String _formatArea(Locale locale, double value) {
    if (value == value.roundToDouble()) {
      return formatLocalizedNumber(value.round(), locale);
    }
    return formatLocalizedNumber(double.parse(value.toStringAsFixed(1)), locale);
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
}
