import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../features/favorites/presentation/widgets/favorite_heart_button.dart';
import '../../../features/listing_form/domain/entities/listing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/util/localized_numbers.dart';
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
import 'verified_badge.dart';

/// The unified listing card used by every feed (Home, Search, Favorites,
/// Recently-viewed).
///
/// Phase 035 craft wave — the three [ListingViewMode] densities are REAL now
/// (the switcher used to be a dead control):
///  - **comfortable** — big photo, verified/purpose marks, specs strip and a
///    WhatsApp contact button;
///  - **balanced** — smaller photo, no contact button (whole card opens the
///    detail);
///  - **compact** — a horizontal thumbnail row with a round WhatsApp action.
///
/// The WhatsApp action actually launches WhatsApp (`wa.me`) when the listing
/// carries a phone; it falls back to opening the detail page otherwise.
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

  static const double _photoHComfortable = 214;
  static const double _photoHBalanced = 160;
  static const double _compactRowH = 112;
  static const BorderRadiusDirectional _photoRadius =
      BorderRadiusDirectional.vertical(top: Radius.circular(AppRadii.xl));

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final elevation = AppElevation.of(context);

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
            child: switch (mode) {
              ListingViewMode.compact => _buildCompact(context),
              ListingViewMode.balanced => _buildStacked(
                context,
                photoHeight: _photoHBalanced,
                withPurposePill: false,
                withWhatsappButton: false,
              ),
              ListingViewMode.comfortable => _buildStacked(
                context,
                photoHeight: _photoHComfortable,
                withPurposePill: true,
                withWhatsappButton: true,
              ),
            },
          ),
        ),
      ),
    );
  }

  // ── comfortable / balanced (stacked photo-over-body) ──────────────────────

  Widget _buildStacked(
    BuildContext context, {
    required double photoHeight,
    required bool withPurposePill,
    required bool withWhatsappButton,
  }) {
    final styles = AppTextStyles.of(context);
    final gradients = AppGradients.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasSpecs =
        data.rooms != null || data.bathrooms != null || data.areaSize != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: photoHeight,
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
                decoration: BoxDecoration(gradient: gradients.photoTopScrim),
              ),
              DecoratedBox(
                decoration: BoxDecoration(gradient: gradients.photoScrim),
              ),
              PositionedDirectional(
                top: AppSpacing.md,
                start: AppSpacing.md,
                end: AppSpacing.md,
                child: Row(
                  children: [
                    if (data.isVerified == true) const VerifiedBadge(),
                    const Spacer(),
                    FavoriteHeartButton(
                      listingId: data.id,
                      style: FavoriteHeartStyle.onImage,
                    ),
                  ],
                ),
              ),
              if (withPurposePill)
                PositionedDirectional(
                  bottom: AppSpacing.md,
                  start: AppSpacing.md,
                  child: _purposePill(context),
                ),
            ],
          ),
        ),
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
              if (withWhatsappButton) ...[
                const SizedBox(height: AppSpacing.md),
                _whatsappButton(context, l10n),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── compact (horizontal row) ───────────────────────────────────────────────

  Widget _buildCompact(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return SizedBox(
      height: _compactRowH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _compactRowH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(
                  url: data.imageUrl,
                  heroTag: listingImageHeroTag(data.id),
                  semanticLabel: l10n.image_unavailable,
                ),
                if (data.isVerified == true)
                  const PositionedDirectional(
                    top: AppSpacing.xs,
                    start: AppSpacing.xs,
                    child: VerifiedBadge(compact: true),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.title.isEmpty ? '—' : data.title,
                    style: styles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _priceLine(styles),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _compactMetaLine(l10n, locale),
                    style: styles.labelMedium.copyWith(color: colors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
            child: Center(child: _whatsappRoundButton(context, l10n)),
          ),
        ],
      ),
    );
  }

  /// `دمشق · المزة · ٣ غرف · ١٢٠ م²` — one muted meta line for the compact row.
  String _compactMetaLine(AppLocalizations l10n, Locale locale) {
    final parts = <String>[
      if (data.locationText.isNotEmpty && data.locationText != '—')
        data.locationText,
      if (data.rooms != null)
        '${formatLocalizedNumber(data.rooms!, locale)} ${l10n.spec_rooms_label}',
      if (data.areaSize != null)
        '${formatLocalizedNumber(data.areaSize!.round(), locale)} ${l10n.spec_area_unit}',
    ];
    return parts.join(' · ');
  }

  // ── shared pieces ──────────────────────────────────────────────────────────

  void _openDetail(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    context.go(AppRoutes.listingDetailsFor(data.id));
  }

  /// Launches WhatsApp for the listing's phone; falls back to the detail page
  /// when no phone is available or the launch fails.
  Future<void> _contactWhatsApp(BuildContext context) async {
    final phone = data.whatsappPhone;
    if (phone == null || phone.trim().isEmpty) {
      _openDetail(context);
      return;
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.https('wa.me', '/$digits');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _openDetail(context);
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
        style: styles.labelMedium.copyWith(color: colors.onPhoto),
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
    final locale = Localizations.localeOf(context);

    Widget item(IconData icon, String text) => Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppSpacing.lg, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: styles.labelMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    // One labelling convention for all three specs (the old row labelled
    // rooms, left bathrooms a bare number, and used Western digits).
    final specs = <Widget>[
      if (data.rooms != null)
        item(
          LucideIcons.bed_double,
          '${formatLocalizedNumber(data.rooms!, locale)} ${l10n.spec_rooms_label}',
        ),
      if (data.bathrooms != null)
        item(
          LucideIcons.bath,
          '${formatLocalizedNumber(data.bathrooms!, locale)} ${l10n.spec_baths_label}',
        ),
      if (data.areaSize != null)
        item(
          LucideIcons.ruler,
          '${formatLocalizedNumber(data.areaSize!.round(), locale)} ${l10n.spec_area_unit}',
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
        onTap: () => _contactWhatsApp(context),
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
                style: styles.labelLarge.copyWith(color: colors.onWhatsapp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whatsappRoundButton(BuildContext context, AppLocalizations l10n) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.whatsapp,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _contactWhatsApp(context),
        child: SizedBox(
          width: kAppMinTouchTarget,
          height: kAppMinTouchTarget,
          child: Icon(
            LucideIcons.message_circle,
            size: AppSpacing.xl,
            color: colors.onWhatsapp,
            semanticLabel: l10n.cta_whatsapp,
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
