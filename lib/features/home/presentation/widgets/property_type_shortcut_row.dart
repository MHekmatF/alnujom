import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/reduce_motion.dart';
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final reduce = reduceMotion(context);

    return SizedBox(
      // Scale the row height with the text scale so chips don't clip at large
      // font sizes (a11y / large-text resilience).
      height: MediaQuery.textScalerOf(context).scale(48),
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
          // Phase 25 (Claude Design) — clean filled pill (recessed surface,
          // borderless); navigation shortcut, so no selected state on home.
          final chip = PressScale(
            child: ActionChip(
              avatar: Icon(
                _icon(type),
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              label: Text(label),
              labelStyle: styles.labelLarge.copyWith(color: colors.onSurface),
              backgroundColor: colors.surfaceVariant,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              onPressed: () {
                HapticFeedback.selectionClick();
                context.go(AppRoutes.search, extra: type);
              },
            ),
          );
          if (reduce) return chip;
          // Subtle cascade as the row appears (delay capped so later chips
          // don't lag); slides in from the inline-start edge.
          final step = index.clamp(0, 6);
          return chip
              .animate()
              .fadeIn(duration: AppMotion.base, delay: AppMotion.stagger * step)
              .slideX(
                begin: 0.12,
                end: 0,
                duration: AppMotion.entrance,
                curve: AppMotion.curve,
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
