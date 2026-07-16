// lib/features/map/presentation/widgets/marker_preview_popover.dart
//
// Phase 15 Sub-Phase E (T048) — bottom-anchored card popover surfacing the
// minimal preview projection of the tapped marker per FR-001. Tap →
// `context.go(AppRoutes.listingDetailsFor(marker.id))` (Phase 13 route
// helper).
//
// Restyled in the Phase-33 royal-blue DS pass to match the home listing card:
// a rounded, hairline-outlined, softly-shadowed `colors.card` surface holding a
// thumbnail, the title, a soft-primary purpose tag + property-type chip, and a
// bold blue DS price line. No data / routing / logic change — purely visual.
//
// Price formatting (R-65 / Phase 13 home-feed parity):
//   • Resolve [Currency] from `getIt<ListCurrencies>()` (FutureBuilder).
//   • Anonymous fallback: render the marker's primaryCurrencyCode verbatim
//     when the catalog lookup fails. Cross-currency conversion via the
//     user's `display_currency` is forward-stated (same Phase-13 footprint).
//
// FR-003a visual indicator: when `marker.isApproximate`, render a localized
// "Approximate location" badge.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../currencies/domain/usecases/list_currencies.dart';
import '../../../favorites/presentation/widgets/favorite_heart_button.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/map_marker.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';

class MarkerPreviewPopover extends StatefulWidget {
  const MarkerPreviewPopover({super.key, required this.marker});

  final MapMarker marker;

  @override
  State<MarkerPreviewPopover> createState() => _MarkerPreviewPopoverState();
}

class _MarkerPreviewPopoverState extends State<MarkerPreviewPopover> {
  // Cache per-popover instance; mirrors Phase 13 HomePage pattern where the
  // currency catalog is fetched once per page lifetime.
  late final Future<List<Currency>> _currenciesFuture;

  @override
  void initState() {
    super.initState();
    _currenciesFuture = getIt<ListCurrencies>().call(activeOnly: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final locale = Localizations.localeOf(context);

    // DS card surface — matches the home listing card chrome (radius lg,
    // hairline outline, soft level-2 lift) so the on-map preview reads as the
    // same family of card.
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level2,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () =>
              context.go(AppRoutes.listingDetailsFor(widget.marker.id)),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PopoverImage(imageUrl: widget.marker.mainImagePath, l10n: l10n),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.marker.title.isEmpty ? '—' : widget.marker.title,
                        style: styles.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _Tag(
                            label: _purposeLabel(l10n, widget.marker.purpose),
                            color: colors.primary,
                            background: colors.primaryContainer,
                          ),
                          _Tag(
                            label: _propertyTypeLabel(
                              l10n,
                              widget.marker.propertyType,
                            ),
                            color: colors.onSurfaceVariant,
                            background: colors.surfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FutureBuilder<List<Currency>>(
                        future: _currenciesFuture,
                        builder: (context, snap) {
                          final byCode = <String, Currency>{
                            for (final c in snap.data ?? const <Currency>[])
                              c.code: c,
                          };
                          // Bold blue DS price line — the loudest figure in the
                          // preview (matches the home-card price treatment).
                          return Text(
                            _formatPrice(byCode, locale),
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.start,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: styles.priceMedium,
                          );
                        },
                      ),
                      if (widget.marker.isApproximate) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.info,
                              size: AppSpacing.lg,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                l10n.map_marker_approximate_location_label,
                                style: styles.labelMedium.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FavoriteHeartButton(listingId: widget.marker.id),
                          TextButton(
                            onPressed: () => context.go(
                              AppRoutes.listingDetailsFor(widget.marker.id),
                            ),
                            child: Text(l10n.map_marker_view_details_action),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  color: colors.onSurfaceVariant,
                  onPressed: () =>
                      context.read<MapBloc>().add(const PopoverDismissed()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(Map<String, Currency> byCode, Locale locale) {
    final currency = byCode[widget.marker.primaryCurrencyCode];
    if (currency == null) {
      // Anonymous fallback / catalog miss — show the verbatim amount + ISO
      // code rather than crashing, matching Phase 13's home-feed convention.
      final amount = widget.marker.primaryAmount;
      final code = widget.marker.primaryCurrencyCode;
      return '$amount $code';
    }
    return MoneyFormatter.format(
      Money(
        amount: widget.marker.primaryAmount,
        currencyCode: widget.marker.primaryCurrencyCode,
      ),
      locale: locale,
      currency: currency,
    );
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

class _PopoverImage extends StatelessWidget {
  const _PopoverImage({required this.imageUrl, required this.l10n});

  final String? imageUrl;
  final AppLocalizations l10n;

  static const double _kSize = 72;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final placeholder = Container(
      width: _kSize,
      height: _kSize,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.md),
      ),
      child: Icon(
        LucideIcons.image_off,
        color: colors.onSurfaceVariant,
        semanticLabel: l10n.map_marker_image_unavailable,
      ),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: appRadius(AppRadii.md),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: _kSize,
        height: _kSize,
        fit: BoxFit.cover,
        placeholder: (context, _) => ColoredBox(
          color: colors.surfaceVariant,
          child: const SizedBox(width: _kSize, height: _kSize),
        ),
        errorWidget: (context, _, __) => placeholder,
      ),
    );
  }
}

/// A soft tinted DS tag chip (pill) — a [background] fill with [color] text.
/// Used for the purpose (soft-primary) and property-type (soft-neutral) signals
/// on the preview card.
class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(label, style: styles.labelMedium.copyWith(color: color)),
      ),
    );
  }
}
