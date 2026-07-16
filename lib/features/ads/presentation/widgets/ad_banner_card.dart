// lib/features/ads/presentation/widgets/ad_banner_card.dart
//
// Phase 21 (spec/021-ads-banners) — AdBannerCard (T032).
// Phase 035 v2 (DC "Blue Crown") — restyled to the DC sponsored-slot card
// (`AlNujom.dc.html`): a bordered surface card with a "إعلان" campaign-chip
// disclosure header, the advertiser's creative, its caption, and a "اعرف
// المزيد" CTA footer separated by a hairline. Non-intrusive, honestly labelled,
// and card-consistent with the feed. All sizing/spacing via theme tokens.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/serving_ad.dart';

class AdBannerCard extends StatelessWidget {
  const AdBannerCard({super.key, required this.ad, required this.onTap});

  final ServingAd ad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final caption = isArabic ? ad.captionAr : ad.captionEn;

    final imageUrl = Supabase.instance.client.storage
        .from('ads')
        .getPublicUrl(ad.imagePath);

    return PressScale(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: appRadius(AppRadii.card),
          border: Border.all(color: colors.outline),
        ),
        child: ClipRRect(
          borderRadius: appRadius(AppRadii.card),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // "إعلان" disclosure chip header — reads honestly as an ad.
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _SponsoredChip(label: l10n.ad_sponsored_label),
                    ),
                  ),
                  // The advertiser's creative.
                  AspectRatio(
                    aspectRatio: 16 / 7,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          ColoredBox(color: colors.surfaceVariant),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: colors.surfaceVariant,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  if (caption != null && caption.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: styles.bodyMedium.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  // CTA footer, separated by a hairline like the DC card.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: colors.outline)),
                    ),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.ad_learn_more,
                              style: styles.labelLarge.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(
                              Icons.chevron_left,
                              size: 17,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The DC "إعلان" disclosure chip — a tonal surface pill with a campaign icon.
class _SponsoredChip extends StatelessWidget {
  const _SponsoredChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign, size: 13, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: styles.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
