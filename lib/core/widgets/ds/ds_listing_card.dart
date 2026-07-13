import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../features/favorites/presentation/widgets/favorite_heart_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/util/localized_numbers.dart';
import '../../routing/app_router.dart';
import '../../settings/listing_view_mode.dart';
import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';
import '../app_network_image.dart';
import '../hero_tags.dart';
import '../press_scale.dart';
import 'ds_listing_card_data.dart';

/// The unified listing card, rebuilt to the approved **DC "Blue Crown"** design
/// (`specs/035-redesign-ground-up/DESIGN-DC.md`, `AlNujom.dc.html`).
///
/// The DC ships a single card anatomy in two contexts:
///  - **feed / results** (default) — full-width photo (16/10), verified stamp,
///    save heart, price + icon-led specs + title + location·ago, a hairline,
///    then a publisher row with tonal **اتصال** and green **واتساب** buttons;
///  - **featured** ([featured] = `true`, the 250 px home rail) — adds a gold
///    "مميّز" badge, drops the heart, and drops the ago/hairline/publisher row
///    for a tighter thumbnail.
///
/// [mode] is retained for API compatibility (the density switcher) but the DC
/// has one card style, so every mode renders the feed card — [featured] is the
/// only real visual variant.
class DsListingCard extends StatelessWidget {
  const DsListingCard({
    required this.data,
    this.mode = ListingViewMode.comfortable,
    this.onTap,
    this.featured = false,
    super.key,
  });

  final DsListingCardData data;

  /// Retained for API compatibility with the density switcher. All densities
  /// render the DC feed card; [featured] drives the only real variant.
  final ListingViewMode mode;

  /// Overrides the default tap behaviour (navigate to the listing detail via
  /// `context.go`). Search passes `context.push` here so its stack survives.
  final VoidCallback? onTap;

  /// DC featured-rail variant: gold "مميّز" badge, no heart, no publisher /
  /// contact row, tighter type. The Home featured rail passes `true`.
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PressScale(
      // DC: feed card active scale(.995), featured scale(.99).
      scale: featured ? 0.99 : 0.995,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: appRadius(AppRadii.card),
          border: Border.all(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _openDetail(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_image(context), _body(context)],
            ),
          ),
        ),
      ),
    );
  }

  // ── image + overlays ────────────────────────────────────────────────────────

  Widget _image(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colors.surfaceVariant),
          AppNetworkImage(
            url: data.imageUrl,
            // A featured listing can also appear in the feed below; only the
            // feed card claims the shared Hero tag so the two never collide.
            heroTag: featured ? null : listingImageHeroTag(data.id),
            semanticLabel: l10n.image_unavailable,
          ),
          // Trust cluster — visually top-right in Arabic RTL (logical start),
          // matching the DC. Featured prepends the gold "مميّز" chip.
          if (featured || data.isVerified == true)
            PositionedDirectional(
              top: AppSpacing.sm,
              start: AppSpacing.sm,
              child: Row(
                children: [
                  if (featured) _goldChip(context),
                  if (featured && data.isVerified == true)
                    const SizedBox(width: AppSpacing.xs),
                  if (data.isVerified == true) _verifiedChip(context),
                ],
              ),
            ),
          // Save heart — visually top-left in RTL (logical end); feed only.
          if (!featured)
            PositionedDirectional(
              top: AppSpacing.sm,
              end: AppSpacing.sm,
              child: FavoriteHeartButton(
                listingId: data.id,
                style: FavoriteHeartStyle.onImage,
              ),
            ),
          // NOTE: the DC renders a photo-count chip (bottom-left) but
          // DsListingCardData carries no photo count — the slot is omitted
          // until that field lands (see the field-gap report).
        ],
      ),
    );
  }

  Widget _verifiedChip(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    return _imageChip(
      background: colors.verifiedContainer,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: colors.onSuccess),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            l10n.detail_verified_badge,
            style: styles.labelSmall.copyWith(
              color: colors.onSuccess,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goldChip(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    return _imageChip(
      background: colors.goldContainer,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 13, color: colors.tertiary),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            l10n.home_featured_badge,
            style: styles.labelSmall.copyWith(
              color: colors.tertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageChip({required Color background, required Widget child}) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: appRadius(AppRadii.sm),
      ),
      child: child,
    );
  }

  // ── body ────────────────────────────────────────────────────────────────────

  Widget _body(BuildContext context) {
    final colors = AppColors.of(context);
    final hasSpecs =
        data.rooms != null || data.bathrooms != null || data.areaSize != null;

    final children = <Widget>[
      _priceRow(context),
      if (hasSpecs) ...[
        const SizedBox(height: AppSpacing.sm),
        _specsRow(context),
      ],
      const SizedBox(height: AppSpacing.sm),
      _title(context),
      const SizedBox(height: AppSpacing.xs),
      _locationRow(context),
      if (!featured) ...[
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 1,
          child: ColoredBox(color: colors.outline),
        ),
        const SizedBox(height: AppSpacing.sm),
        _publisherRow(context),
      ],
    ];

    return Padding(
      // DC body padding 10/12/12 (featured 9/11/11) → snapped to the scale.
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _priceRow(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final secondary = data.pricePerMeterText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          data.priceText,
          // Prices read left-to-right (Western digits) even in RTL.
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: styles.priceMedium.copyWith(
            fontSize: featured ? 17 : 18,
            color: colors.onSurface,
          ),
        ),
        if (secondary != null && secondary.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.labelMedium.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _specsRow(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final iconSize = featured ? 16.0 : 17.0;
    final textStyle = styles.labelMedium.copyWith(
      fontSize: featured ? 12 : 13,
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );

    String area() =>
        '${formatLocalizedNumber(data.areaSize!.round(), locale)} '
        '${l10n.spec_area_unit}';

    // The view model carries no property type; treat a listing with an area but
    // no rooms/baths as land (matches how land is entered).
    final isLand =
        data.rooms == null && data.bathrooms == null && data.areaSize != null;

    final items = <Widget>[];
    if (isLand) {
      items.add(
        _spec(Icons.landscape, l10n.propertyTypeLand, iconSize, textStyle, colors),
      );
      items.add(_spec(Icons.square_foot, area(), iconSize, textStyle, colors));
    } else {
      if (data.rooms != null) {
        items.add(
          _spec(
            Icons.king_bed,
            formatLocalizedNumber(data.rooms!, locale),
            iconSize,
            textStyle,
            colors,
          ),
        );
      }
      if (data.bathrooms != null) {
        items.add(
          _spec(
            Icons.bathtub,
            formatLocalizedNumber(data.bathrooms!, locale),
            iconSize,
            textStyle,
            colors,
          ),
        );
      }
      if (data.areaSize != null) {
        items.add(_spec(Icons.square_foot, area(), iconSize, textStyle, colors));
      }
    }

    final row = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        row.add(const SizedBox(width: AppSpacing.sm));
        row.add(_dot(colors));
        row.add(const SizedBox(width: AppSpacing.sm));
      }
      row.add(items[i]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: row);
  }

  Widget _spec(
    IconData icon,
    String text,
    double iconSize,
    TextStyle style,
    AppColors colors,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: style, textDirection: TextDirection.ltr),
      ],
    );
  }

  /// DC 3px dot separator between specs (currentColor @ .45).
  Widget _dot(AppColors colors) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: colors.onSurfaceVariant.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _title(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Text(
      data.title.isEmpty ? '—' : data.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: styles.bodyMedium.copyWith(
        fontSize: featured ? 13 : 14,
        color: colors.onSurface,
      ),
    );
  }

  Widget _locationRow(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final style = styles.labelMedium.copyWith(
      color: colors.textMuted,
      fontWeight: FontWeight.w400,
    );
    // Featured shows location only; the feed appends "· <published ago>".
    final ago = (!featured && data.publishedAt != null)
        ? _formatTimeSince(l10n, data.publishedAt!)
        : null;
    return Row(
      children: [
        Icon(Icons.location_on, size: 15, color: colors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            data.locationText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (ago != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text('·', style: style),
          const SizedBox(width: AppSpacing.xs),
          Text(ago, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ],
      ],
    );
  }

  Widget _publisherRow(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  data.agencyName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.labelMedium.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              // No dedicated agency-verified flag on the view model; the
              // listing's verified state stands in for the publisher tick.
              if (data.isVerified == true) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.verified, size: 15, color: colors.primary),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _contactButton(
          context,
          label: l10n.cta_call,
          icon: Icons.call,
          background: colors.primaryContainer,
          foreground: colors.onPrimaryContainer,
          onTap: () => _contactCall(context),
        ),
        const SizedBox(width: AppSpacing.sm),
        _contactButton(
          context,
          label: l10n.cta_whatsapp,
          icon: Icons.chat,
          background: colors.verifiedContainer,
          foreground: colors.onSuccess,
          onTap: () => _contactWhatsApp(context),
        ),
      ],
    );
  }

  Widget _contactButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    final styles = AppTextStyles.of(context);
    return Material(
      color: background,
      borderRadius: appRadius(AppRadii.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
          ),
          child: SizedBox(
            // DC button height 33 → nearest scale step.
            height: AppSpacing.xxl,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: styles.labelMedium.copyWith(
                    fontSize: 13,
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── behaviour ───────────────────────────────────────────────────────────────

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

  /// Opens the phone dialer (`tel:`) for the listing's contact number; falls
  /// back to the detail page when no phone is available or the launch fails.
  /// (The view model exposes a single [DsListingCardData.whatsappPhone]; it
  /// doubles as the call number until a dedicated field exists.)
  Future<void> _contactCall(BuildContext context) async {
    final phone = data.whatsappPhone;
    if (phone == null || phone.trim().isEmpty) {
      _openDetail(context);
      return;
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$digits');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _openDetail(context);
  }

  /// Relative "published ago" line, reusing the project's existing convention
  /// (same keys as `home_listing_card.dart` / `rejection_reason_banner.dart`).
  String _formatTimeSince(AppLocalizations l10n, DateTime when) {
    final delta = DateTime.now().difference(when);
    if (delta.inMinutes < 1) return l10n.adminQueueSubmittedAtJustNow;
    if (delta.inHours < 1) {
      return l10n.adminQueueSubmittedAtMinutes(delta.inMinutes);
    }
    if (delta.inDays < 1) {
      return l10n.adminQueueSubmittedAtHours(delta.inHours);
    }
    return l10n.adminQueueSubmittedAtDays(delta.inDays);
  }
}
