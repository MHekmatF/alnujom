import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/gradients.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';

/// Design #8 "Glass / Depth" — the category filter chips row directly under the
/// search bar: an "الكل" chip (indigo-gradient, selected) followed by frosted-
/// glass type chips. Each opens Search pre-filtered by that [PropertyType].
class HomeCategoriesSection extends StatelessWidget {
  const HomeCategoriesSection({super.key});

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

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: SizedBox(
        height: MediaQuery.textScalerOf(context).scale(46),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
          ),
          itemCount: _types.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _Chip(
                label: l10n.filterChipAll,
                selected: true,
                onTap: () => context.go(AppRoutes.search),
              );
            }
            final type = _types[i - 1];
            return _Chip(
              label: _label(l10n, type),
              selected: false,
              onTap: () => context.go(AppRoutes.search, extra: type),
            );
          },
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n, PropertyType type) => switch (type) {
    PropertyType.apartment => l10n.propertyTypeApartment,
    PropertyType.villa => l10n.propertyTypeVilla,
    PropertyType.land => l10n.propertyTypeLand,
    PropertyType.shop => l10n.propertyTypeShop,
    PropertyType.office => l10n.propertyTypeOffice,
    PropertyType.farm => l10n.propertyTypeFarm,
    PropertyType.warehouse => l10n.propertyTypeWarehouse,
    PropertyType.other => l10n.propertyTypeOther,
  };
}

class _Chip extends StatelessWidget {
  const _Chip({
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
    final gradients = AppGradients.of(context);

    final text = Text(
      label,
      style: styles.labelLarge.copyWith(
        color: selected ? colors.onPrimary : colors.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );

    final content = Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
        ),
        child: text,
      ),
    );

    void handleTap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    if (selected) {
      return PressScale(
        child: Material(
          color: Colors.transparent,
          borderRadius: appRadius(AppRadii.md),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: gradients.primaryGradient,
              borderRadius: appRadius(AppRadii.md),
            ),
            child: InkWell(onTap: handleTap, child: content),
          ),
        ),
      );
    }

    return PressScale(
      child: GlassPanel(
        radius: AppRadii.md,
        blur: 12,
        tintOpacity: 0.78,
        child: Material(
          color: Colors.transparent,
          child: InkWell(onTap: handleTap, child: content),
        ),
      ),
    );
  }
}
