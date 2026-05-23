import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// Phase 12 (spec/012-listing-approval) — `ListingGallery` is the ONE
// shared-widget exception to Constitution IX's "no `package:supabase_flutter`
// outside `data/datasources/`" rule, per `phase12-shared-display-widgets.md`.
// The import is narrowly confined to resolving the public URL via the
// storage client for an `is_main`-first ordered gallery rendered by
// `cached_network_image`. No other Supabase API surface is touched here.
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../../core/theme/spacing.dart';
import '../../../../features/listing_form/domain/entities/listing_media.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 12 Q8=A shared widget — horizontal carousel of media items.
/// Items are sorted by `ordering ASC` with `is_main=true` floated to the
/// front. Each item renders 16:9. Empty list → 16:9 placeholder card.
class ListingGallery extends StatelessWidget {
  const ListingGallery({super.key, required this.media});

  final List<ListingMedia> media;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (media.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          alignment: Alignment.center,
          child: Text(
            l10n.mediaGalleryEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final sorted = [...media];
    sorted.sort((a, b) {
      if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
      return a.ordering.compareTo(b.ordering);
    });

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: PageView.builder(
        itemCount: sorted.length,
        itemBuilder: (ctx, index) => _GalleryItem(media: sorted[index]),
      ),
    );
  }
}

class _GalleryItem extends StatelessWidget {
  const _GalleryItem({required this.media});

  final ListingMedia media;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (media.kind == ListingMediaKind.image && media.storagePath != null) {
      final url = Supabase.instance.client.storage
          .from('listing-images')
          .getPublicUrl(media.storagePath!);
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: theme.colorScheme.surfaceContainerHigh,
          ),
          errorWidget: (_, __, ___) => const _MediaPlaceholder(
            icon: Icons.broken_image_outlined,
          ),
        ),
      );
    }

    // Video or external-link or storagePath-missing-image: render the
    // static play-button overlay per Phase 11 FR-013.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      alignment: Alignment.center,
      child: _MediaPlaceholder(
        icon: media.kind == ListingMediaKind.video
            ? Icons.play_circle_outline
            : Icons.image_outlined,
        label: AppLocalizations.of(context)!.mediaGalleryVideoPlay,
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            label!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
