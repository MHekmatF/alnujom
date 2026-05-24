import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';

/// Phase 14 — property-type shortcut chips; each chip navigates to SearchPage
/// pre-filtered by that type (SC-011 entry point 2, GoRouterState.extra = type).
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
            onPressed: () => context.go(AppRoutes.search, extra: type),
          );
        },
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
