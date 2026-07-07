import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';

/// Phase 035 (Home revamp) — the "التصنيفات / Categories" section: a bold
/// section header with a "عرض الكل" action (opens the full browse) over a
/// horizontal strip of icon tiles. Each tile opens Search pre-filtered by that
/// [PropertyType]. Replaces the thin chip row for a more prominent, scannable
/// category browse.
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: AppSpacing.xs,
                height: AppSpacing.xl,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: appRadius(AppRadii.pill),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(l10n.home_categories_title, style: styles.titleLarge),
              ),
              _SeeAllButton(
                label: l10n.home_see_all,
                onTap: () => context.go(AppRoutes.search),
              ),
            ],
          ),
        ),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(96),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            itemCount: _types.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => _CategoryTile(type: _types[i]),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.type});

  final PropertyType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return PressScale(
      child: InkWell(
        borderRadius: appRadius(AppRadii.lg),
        onTap: () {
          HapticFeedback.selectionClick();
          context.go(AppRoutes.search, extra: type);
        },
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  // Blue+grey: grey tile, blue glyph — blue reads as a sparing
                  // accent instead of a fill.
                  color: colors.surfaceVariant,
                  borderRadius: appRadius(AppRadii.lg),
                  border: Border.all(color: colors.outline),
                ),
                child: Icon(
                  _icon(type),
                  color: colors.primary,
                  size: AppSpacing.xl,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _label(l10n, type),
                style: styles.labelMedium.copyWith(color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
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

  IconData _icon(PropertyType type) => switch (type) {
    PropertyType.apartment => Icons.apartment,
    PropertyType.villa => Icons.villa_outlined,
    PropertyType.land => Icons.landscape_outlined,
    PropertyType.shop => Icons.storefront_outlined,
    PropertyType.office => Icons.business_center_outlined,
    PropertyType.farm => Icons.agriculture_outlined,
    PropertyType.warehouse => Icons.warehouse_outlined,
    PropertyType.other => Icons.category_outlined,
  };
}

/// A compact "عرض الكل / View all" text action used by Home section headers.
class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return InkWell(
      borderRadius: appRadius(AppRadii.pill),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: kAppMinTouchTarget),
        alignment: AlignmentDirectional.center,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: styles.labelLarge.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left
                  : Icons.chevron_right,
              size: AppSpacing.lg,
              color: colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
