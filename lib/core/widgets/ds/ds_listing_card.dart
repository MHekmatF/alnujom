import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

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
import '../hero_tags.dart';
import '../press_scale.dart';
import '../property_specs.dart';
import '../status_pill.dart';
import 'ds_listing_card_data.dart';

/// Phase 035 — the unified listing card used by every feed (Home, Search,
/// Favorites, Recently-viewed). One widget, three densities driven by
/// [ListingViewMode]; the operator-verification slots (verified badge,
/// freshness, deed) render only when their [DsListingCardData] fields are
/// present, so it degrades gracefully before the Stage-3 backend lands.
class DsListingCard extends StatelessWidget {
  const DsListingCard({
    required this.data,
    this.mode = ListingViewMode.balanced,
    super.key,
  });

  final DsListingCardData data;
  final ListingViewMode mode;

  // Design-system image geometry (px), per view mode.
  static const double _comfortableImageH = 210;
  static const double _balancedImageH = 180;
  static const double _compactThumbW = 110;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      ListingViewMode.comfortable => _buildComfortable(context),
      ListingViewMode.balanced => _buildBalanced(context),
      ListingViewMode.compact => _buildCompact(context),
    };
  }

  void _openDetail(BuildContext context) =>
      context.go(AppRoutes.listingDetailsFor(data.id));

  // ── Shared bits ────────────────────────────────────────────────────────

  Widget _cardShell(BuildContext context, {required Widget child}) {
    final colors = AppColors.of(context);
    final elevation = AppElevation.of(context);
    return PressScale(
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: appRadius(AppRadii.lg),
          border: Border.all(color: colors.outline),
          boxShadow: elevation.level1,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: () => _openDetail(context), child: child),
        ),
      ),
    );
  }

  /// The over-image badge cluster (leading edge): gold مميّز stacked over the
  /// verified pill (when verified) over the transaction-mode pill.
  Widget _imageBadges(BuildContext context, {bool small = false}) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final pills = <Widget>[
      if (data.isFeatured)
        StatusPill(
          label: l10n.home_featured_badge,
          color: colors.tertiary,
          foreground: Theme.of(context).colorScheme.onTertiary,
          icon: LucideIcons.star,
        ),
      if (data.isVerified == true)
        StatusPill(
          label: data.verifiedAgoText ?? l10n.detail_verified_badge,
          color: colors.verified,
          foreground: colors.onSuccess,
          icon: LucideIcons.badge_check,
        ),
      StatusPill(label: _purposeLabel(l10n), color: _purposeColor(colors)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < pills.length; i++) ...[
          if (i > 0) SizedBox(height: small ? AppSpacing.xxs : AppSpacing.xs),
          pills[i],
        ],
      ],
    );
  }

  Widget _image(
    BuildContext context, {
    required double? height,
    required double? width,
    required double radius,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: height,
      width: width,
      child: ClipRRect(
        borderRadius: appRadius(radius),
        child: AppNetworkImage(
          url: data.imageUrl,
          heroTag: listingImageHeroTag(data.id),
          semanticLabel: l10n.image_unavailable,
        ),
      ),
    );
  }

  Widget _priceLine(AppTextStyles styles, {bool large = true}) => Text(
    data.priceText,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.start,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: large ? styles.priceLarge : styles.priceMedium,
  );

  Widget _metaLine(BuildContext context, {int maxLines = 1}) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Text(
      _metaText(),
      style: styles.labelMedium.copyWith(color: colors.textMuted),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ── Mode 1 — Comfortable (photo-first) ──────────────────────────────────

  Widget _buildComfortable(BuildContext context) {
    final styles = AppTextStyles.of(context);
    final gradients = AppGradients.of(context);
    return _cardShell(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              _image(
                context,
                height: _comfortableImageH,
                width: double.infinity,
                radius: AppRadii.lg,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradients.photoTopScrim),
                ),
              ),
              PositionedDirectional(
                top: AppSpacing.md,
                start: AppSpacing.md,
                child: _imageBadges(context),
              ),
              PositionedDirectional(
                top: AppSpacing.md,
                end: AppSpacing.md,
                child: FavoriteHeartButton(
                  listingId: data.id,
                  style: FavoriteHeartStyle.onImage,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        data.title.isEmpty ? '—' : data.title,
                        style: styles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _priceLine(styles),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _metaLine(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode 2 — Balanced (default) ─────────────────────────────────────────

  Widget _buildBalanced(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final gradients = AppGradients.of(context);
    final hasSpecs = PropertySpecsRow.hasAnyOf(
      rooms: data.rooms,
      bathrooms: data.bathrooms,
      areaSize: data.areaSize?.toDouble(),
    );
    return _cardShell(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              _image(
                context,
                height: _balancedImageH,
                width: double.infinity,
                radius: AppRadii.lg,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradients.photoScrim),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradients.photoTopScrim),
                ),
              ),
              PositionedDirectional(
                top: AppSpacing.md,
                start: AppSpacing.md,
                child: _imageBadges(context),
              ),
              PositionedDirectional(
                top: AppSpacing.md,
                end: AppSpacing.md,
                child: FavoriteHeartButton(
                  listingId: data.id,
                  style: FavoriteHeartStyle.onImage,
                ),
              ),
              if (data.verifiedAgoText != null && data.isVerified == true)
                PositionedDirectional(
                  bottom: AppSpacing.md,
                  end: AppSpacing.md,
                  child: _freshnessPill(context),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _priceLine(styles),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.title.isEmpty ? '—' : data.title,
                  style: styles.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      LucideIcons.map_pin,
                      size: AppSpacing.lg,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        data.locationText,
                        style: styles.bodyMedium.copyWith(
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (hasSpecs) ...[
                  const SizedBox(height: AppSpacing.sm),
                  PropertySpecsRow(
                    rooms: data.rooms,
                    bathrooms: data.bathrooms,
                    areaSize: data.areaSize?.toDouble(),
                    color: colors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode 3 — Compact (dense rows + WhatsApp) ────────────────────────────

  Widget _buildCompact(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return _cardShell(
      context,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                _image(
                  context,
                  height: null,
                  width: _compactThumbW,
                  radius: AppRadii.sm,
                ),
                PositionedDirectional(
                  top: AppSpacing.sm,
                  end: AppSpacing.sm,
                  child: _compactBadge(context),
                ),
              ],
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(child: _priceLine(styles, large: false)),
                        if (data.pricePerMeterText != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            data.pricePerMeterText!,
                            style: styles.labelMedium.copyWith(
                              color: colors.textMuted,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      data.title.isEmpty ? '—' : data.title,
                      style: styles.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    _metaLine(context),
                    if (data.verifiedAgoText != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      _compactStatusLine(context),
                    ],
                  ],
                ),
              ),
            ),
            _compactActions(context),
          ],
        ),
      ),
    );
  }

  Widget _compactActions(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: colors.outline)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteHeartButton(listingId: data.id),
          const SizedBox(height: AppSpacing.sm),
          _WhatsappSquare(onTap: () => _openDetail(context)),
        ],
      ),
    );
  }

  Widget _compactBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    if (data.isFeatured) {
      return StatusPill(
        label: l10n.home_featured_badge,
        color: colors.tertiary,
        foreground: Theme.of(context).colorScheme.onTertiary,
        icon: LucideIcons.star,
      );
    }
    if (data.isVerified == true) {
      return StatusPill(
        label: l10n.detail_verified_badge,
        color: colors.verified,
        foreground: colors.onSuccess,
        icon: LucideIcons.badge_check,
      );
    }
    return StatusPill(label: _purposeLabel(l10n), color: _purposeColor(colors));
  }

  Widget _compactStatusLine(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final verified = data.isVerified == true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified ? LucideIcons.clock : Icons.help_outline,
          size: AppSpacing.md,
          color: verified ? colors.verified : colors.textMuted,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            data.verifiedAgoText!,
            style: styles.labelMedium.copyWith(
              color: verified ? colors.verified : colors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _freshnessPill(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.photoOverlay,
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Text(
        data.verifiedAgoText!,
        style: styles.labelMedium.copyWith(color: colors.onPhoto),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _metaText() {
    final parts = <String>[
      if (data.locationText.isNotEmpty && data.locationText != '—')
        data.locationText,
      if (data.rooms != null) '${data.rooms} غرف',
      if (data.areaSize != null) '${data.areaSize!.round()} م²',
      if (data.deedLabel != null) data.deedLabel!,
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  String _purposeLabel(AppLocalizations l10n) => switch (data.purpose) {
    ListingPurpose.sale => l10n.listingPurposeSale,
    ListingPurpose.rent => l10n.listingPurposeRent,
    ListingPurpose.dailyRent => l10n.listingPurposeDailyRent,
    ListingPurpose.investment => l10n.listingPurposeInvestment,
  };

  Color _purposeColor(AppColors colors) => switch (data.purpose) {
    ListingPurpose.sale => colors.primary,
    ListingPurpose.rent => colors.verified,
    ListingPurpose.dailyRent => colors.accent,
    ListingPurpose.investment => colors.tertiary,
  };
}

/// The compact-row 40×40 WhatsApp square. Opens the listing detail (where the
/// verified contact lives) until Stage 3 threads a direct-launch phone into the
/// feed data.
class _WhatsappSquare extends StatelessWidget {
  const _WhatsappSquare({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.whatsapp,
      borderRadius: appRadius(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: AppSpacing.xxxl,
          height: AppSpacing.xxxl,
          child: Icon(
            LucideIcons.message_circle,
            size: AppSpacing.xl,
            color: colors.onWhatsapp,
          ),
        ),
      ),
    );
  }
}
