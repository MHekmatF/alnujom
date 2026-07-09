// lib/features/ads/presentation/widgets/ad_banner_card.dart
//
// Phase 21 (spec/021-ads-banners) — AdBannerCard (T032).
// Phase 035 (Home revamp) — restyled into a proper inset card: rounded +
// hairline-bordered + softly-shadowed, an "إعلان / Sponsored" label so it reads
// honestly as an ad, a bottom gradient scrim carrying the caption in white, and
// a chevron affordance. All sizing/spacing via theme tokens.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/gradients.dart';
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
    final elevation = AppElevation.of(context);
    final gradients = AppGradients.of(context);
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final caption = isArabic ? ad.captionAr : ad.captionEn;

    final imageUrl = Supabase.instance.client.storage
        .from('ads')
        .getPublicUrl(ad.imagePath);

    return PressScale(
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: appRadius(AppRadii.lg),
            boxShadow: elevation.level1,
          ),
          child: ClipRRect(
            borderRadius: appRadius(AppRadii.lg),
            child: AspectRatio(
              aspectRatio: 16 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
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
                  // Bottom scrim so a white caption stays legible on any image.
                  if (caption != null && caption.isNotEmpty)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: gradients.photoScrim,
                        ),
                      ),
                    ),
                  // "إعلان / Sponsored" label — honest ad disclosure.
                  PositionedDirectional(
                    top: AppSpacing.sm,
                    start: AppSpacing.sm,
                    child: _SponsoredChip(label: l10n.ad_sponsored_label),
                  ),
                  if (caption != null && caption.isNotEmpty)
                    PositionedDirectional(
                      start: AppSpacing.md,
                      end: AppSpacing.md,
                      bottom: AppSpacing.sm,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              caption,
                              style: AppTextStyles.of(
                                context,
                              ).labelLarge.copyWith(color: colors.onPhoto),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.chevron_left,
                            color: colors.onPhoto,
                            size: AppSpacing.lg,
                          ),
                        ],
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
        color: colors.photoOverlay,
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Text(
        label,
        style: styles.labelMedium.copyWith(color: colors.onPhoto),
      ),
    );
  }
}
