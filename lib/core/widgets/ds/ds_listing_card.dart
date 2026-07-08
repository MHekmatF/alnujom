import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../features/favorites/presentation/widgets/favorite_heart_button.dart';
import '../../../features/listing_form/domain/entities/listing.dart';
import '../../../l10n/app_localizations.dart';
import '../../routing/app_router.dart';
import '../../settings/listing_view_mode.dart';
import '../../theme/colors.dart';
import '../../theme/elevation.dart';
import '../../theme/gradients.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';
import '../app_network_image.dart';
import '../glass.dart';
import '../hero_tags.dart';
import '../press_scale.dart';
import 'ds_listing_card_data.dart';

/// Design #8 "Glass / Depth" — the unified listing card used by every feed
/// (Home, Search, Favorites, Recently-viewed): a floating white card with a big
/// photo (over-photo verified badge, glass heart, purpose pill), an Arabic
/// title + location, a bold indigo price, an icon spec row, and a WhatsApp
/// contact button. The [mode] is presentational-only for now (kept for API
/// compatibility) — one premium look regardless of density.
class DsListingCard extends StatelessWidget {
  const DsListingCard({
    required this.data,
    this.mode = ListingViewMode.comfortable,
    this.onTap,
    super.key,
  });

  final DsListingCardData data;
  final ListingViewMode mode;

  /// Overrides the default tap behaviour (navigate to the listing detail via
  /// `context.go`). Search passes `context.push` here so its stack survives.
  final VoidCallback? onTap;

  static const double _photoH = 214;
  static const BorderRadiusDirectional _photoRadius =
      BorderRadiusDirectional.vertical(top: Radius.circular(AppRadii.xl));

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final gradients = AppGradients.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasSpecs =
        data.rooms != null || data.bathrooms != null || data.areaSize != null;

    return PressScale(
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: appRadius(AppRadii.xl),
          border: Border.all(color: colors.outline),
          boxShadow: elevation.level2,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _openDetail(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Photo ─────────────────────────────────────────────────
                SizedBox(
                  height: _photoH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: _photoRadius,
                        child: AppNetworkImage(
                          url: data.imageUrl,
                          heroTag: listingImageHeroTag(data.id),
                          semanticLabel: l10n.image_unavailable,
                        ),
                      ),
                      DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: gradients.photoTopScrim),
                      ),
                      DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: gradients.photoScrim),
                      ),
                      PositionedDirectional(
                        top: AppSpacing.md,
                        start: AppSpacing.md,
                        end: AppSpacing.md,
                        child: Row(
                          children: [
                            if (data.isVerified == true) _verifiedBadge(context),
                            const Spacer(),
                            FavoriteHeartButton(
                              listingId: data.id,
                              style: FavoriteHeartStyle.onImage,
                            ),
                          ],
                        ),
                      ),
                      PositionedDirectional(
                        bottom: AppSpacing.md,
                        start: AppSpacing.md,
                        child: _purposePill(context),
                      ),
                    ],
                  ),
                ),
                // ── Body ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.title.isEmpty ? '—' : data.title,
                                  style: styles.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                _locationRow(context),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _priceLine(styles),
                        ],
                      ),
                      if (hasSpecs) ...[
                        const SizedBox(height: AppSpacing.md),
                        _specsRow(context),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _whatsappButton(context, l10n),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    context.go(AppRoutes.listingDetailsFor(data.id));
  }

  Widget _verifiedBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.verified,
        borderRadius: appRadius(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.badge_check,
            size: AppSpacing.md,
            color: colors.onSuccess,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            l10n.detail_verified_badge,
            style: styles.labelMedium.copyWith(
              color: colors.onSuccess,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _purposePill(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return GlassPanel(
      onDark: true,
      radius: AppRadii.sm,
      blur: 12,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Text(
        _purposeLabel(l10n),
        style: styles.labelMedium.copyWith(
          color: colors.onPhoto,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _locationRow(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Row(
      children: [
        Icon(LucideIcons.map_pin, size: AppSpacing.md, color: colors.primary),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            data.locationText,
            style: styles.labelMedium.copyWith(color: colors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _priceLine(AppTextStyles styles) => Text(
    data.priceText,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.end,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: styles.priceLarge,
  );

  Widget _specsRow(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final numFmt = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );

    Widget item(IconData icon, String text) => Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppSpacing.lg, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: styles.labelMedium.copyWith(color: colors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final specs = <Widget>[
      if (data.rooms != null)
        item(
          LucideIcons.bed_double,
          '${numFmt.format(data.rooms)} ${l10n.spec_rooms_label}',
        ),
      if (data.bathrooms != null)
        item(LucideIcons.bath, numFmt.format(data.bathrooms)),
      if (data.areaSize != null)
        item(
          LucideIcons.ruler,
          '${numFmt.format(data.areaSize!.round())} ${l10n.spec_area_unit}',
        ),
    ];

    final row = <Widget>[];
    for (var i = 0; i < specs.length; i++) {
      if (i > 0) {
        row.add(
          Container(width: 1, height: AppSpacing.lg, color: colors.outline),
        );
      }
      row.add(specs[i]);
    }

    return Container(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      decoration: BoxDecoration(
        border: BorderDirectional(top: BorderSide(color: colors.outline)),
      ),
      child: Row(children: row),
    );
  }

  Widget _whatsappButton(BuildContext context, AppLocalizations l10n) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Material(
      color: colors.whatsapp,
      borderRadius: appRadius(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context),
        child: SizedBox(
          height: kAppMinTouchTarget,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.message_circle,
                size: AppSpacing.xl,
                color: colors.onWhatsapp,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.cta_whatsapp,
                style: styles.labelLarge.copyWith(
                  color: colors.onWhatsapp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _purposeLabel(AppLocalizations l10n) => switch (data.purpose) {
    ListingPurpose.sale => l10n.listingPurposeSale,
    ListingPurpose.rent => l10n.listingPurposeRent,
    ListingPurpose.dailyRent => l10n.listingPurposeDailyRent,
    ListingPurpose.investment => l10n.listingPurposeInvestment,
  };
}
