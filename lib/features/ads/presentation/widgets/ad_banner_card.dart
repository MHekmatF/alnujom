// lib/features/ads/presentation/widgets/ad_banner_card.dart
//
// Phase 21 (spec/021-ads-banners) — AdBannerCard (T032).
//
// Renders a single [ServingAd] as a tappable banner:
//   - [CachedNetworkImage] from the public URL of [ServingAd.imagePath]
//     (resolved via `supabase.storage.from('ads').getPublicUrl(...)`)
//   - Optional locale-matched caption ([captionAr]/[captionEn]) per R-172
//   - All sizing/spacing/styling via Phase 2 theme tokens — NO inline hex,
//     font-size, or hardcoded padding.
//
// The URL resolution is confined here; domain + data layers have zero
// supabase_flutter imports (Constitution IX exception: widget layer only).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../domain/entities/serving_ad.dart';

class AdBannerCard extends StatelessWidget {
  const AdBannerCard({
    super.key,
    required this.ad,
    required this.onTap,
  });

  final ServingAd ad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final caption =
        isArabic ? ad.captionAr : ad.captionEn;

    final imageUrl = Supabase.instance.client.storage
        .from('ads')
        .getPublicUrl(ad.imagePath);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: AspectRatio(
          aspectRatio: 16 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (caption != null && caption.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _CaptionOverlay(caption: caption),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionOverlay extends StatelessWidget {
  const _CaptionOverlay({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: theme.colorScheme.surface.withValues(alpha: 0.75),
      child: Text(
        caption,
        style: theme.textTheme.bodySmall,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
