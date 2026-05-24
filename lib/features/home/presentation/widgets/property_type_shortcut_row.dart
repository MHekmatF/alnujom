import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';

/// Phase 13 — Q1=A stubbed horizontal row of property-type shortcut chips
/// per contracts/phase13-home-page-composition.md §3.
///
/// Eight chips per Phase 10's `PropertyType` enum: apartment, villa, land,
/// shop, office, farm, warehouse, other. Each chip tap shows a 3-second
/// floating snackbar with `home_property_shortcut_coming_soon` parameterized
/// over the tapped type's localized label. NO navigation — the search +
/// filter surface ships in Phase 14.
class PropertyTypeShortcutRow extends StatelessWidget {
  const PropertyTypeShortcutRow({super.key});

  static const _types = <PropertyType>[
    PropertyType.apartment,
    PropertyType.villa,
    PropertyType.land,
    PropertyType.shop,
    PropertyType.office,
    PropertyType.farm,
    PropertyType.warehouse,
    PropertyType.other,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
        ),
        itemCount: _types.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final type = _types[index];
          final label = _label(l10n, type);
          return ActionChip(
            avatar: Icon(_icon(type), size: 18),
            label: Text(label),
            backgroundColor: theme.colorScheme.secondaryContainer,
            onPressed: () => _handleTap(context, l10n, label),
          );
        },
      ),
    );
  }

  void _handleTap(BuildContext context, AppLocalizations l10n, String typeLabel) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.home_property_shortcut_coming_soon(typeLabel)),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _label(AppLocalizations l10n, PropertyType type) {
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

  IconData _icon(PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return Icons.apartment;
      case PropertyType.villa:
        return Icons.villa;
      case PropertyType.land:
        return Icons.landscape;
      case PropertyType.shop:
        return Icons.storefront;
      case PropertyType.office:
        return Icons.business_center;
      case PropertyType.farm:
        return Icons.agriculture;
      case PropertyType.warehouse:
        return Icons.warehouse;
      case PropertyType.other:
        return Icons.category;
    }
  }
}
