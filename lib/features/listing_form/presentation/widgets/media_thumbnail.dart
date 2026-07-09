import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../domain/entities/listing_form_state.dart';
import '../../domain/entities/listing_media.dart';
import '../../domain/repositories/listings_repository.dart';

/// Phase 11 — per-tile widget in the [MediaPicker] grid.
///
/// Renders:
///  - The watermarked image (`kind=image`) via [CachedNetworkImage] per R-29,
///    OR a play-button overlay on a neutral background for `kind=video`
///    (Phase 11 does NOT generate video-frame thumbnails per FR-013).
///  - "main" badge at the top-end corner when `isMain==true` (image-only).
///  - The 1-based ordering badge at the top-start corner.
///  - A long-press action sheet wrapping all three per-thumbnail actions:
///    Set as main (image-only per FR-013), Move up / Move down, Delete.
///
/// Use [MediaThumbnail.ghost] for in-flight upload tiles that have not yet
/// committed a `listing_media` row; the ghost renders the [progress] state.
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    super.key,
    required this.media,
    required this.isEditable,
    this.onSetMain,
    this.onTogglePanorama,
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    this.dragEnabled = false,
  }) : onDismiss = null,
       _ghostProgress = null;

  /// Ghost tile constructor — for in-flight uploads that haven't committed
  /// a `listing_media` row yet. `onDismiss` is wired only when the progress
  /// is `MediaUploadProgressError` — it lets the publisher clear the
  /// orphaned error tile without having to navigate away.
  const MediaThumbnail.ghost({
    super.key,
    required MediaUploadProgress progress,
    this.onDismiss,
  }) : media = null,
       isEditable = false,
       onSetMain = null,
       onTogglePanorama = null,
       onDelete = null,
       onMoveUp = null,
       onMoveDown = null,
       dragEnabled = false,
       _ghostProgress = progress;

  final ListingMedia? media;
  final bool isEditable;
  final VoidCallback? onSetMain;

  /// Spec 026 — toggles this image's 360°/virtual-tour panorama mark. Wired
  /// only for image rows (videos can't be panoramas); null hides the action.
  final VoidCallback? onTogglePanorama;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDismiss;

  /// Phase 029 (F3) — when true, an enclosing [LongPressDraggable] owns the
  /// long-press gesture for drag-reorder, so this tile suppresses its own
  /// long-press action sheet and instead surfaces a small "more actions" handle
  /// (top-end) that opens the same sheet on tap. This keeps every per-thumbnail
  /// action (set main, 360°, move up/down, delete) reachable as the
  /// accessibility fallback while drag-reorder is the primary gesture.
  final bool dragEnabled;
  final MediaUploadProgress? _ghostProgress;

  bool get _isGhost => _ghostProgress != null;

  @override
  Widget build(BuildContext context) {
    // When drag-reorder is enabled, an enclosing LongPressDraggable claims the
    // long-press gesture, so we MUST NOT also wire onLongPress here (the two
    // recognizers would conflict). The action sheet stays reachable via the
    // top-end "more actions" handle instead.
    final useInternalLongPress = !dragEnabled;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: GestureDetector(
        onLongPress: (_isGhost || !isEditable || !useInternalLongPress)
            ? null
            : () => _openActionSheet(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(context),
            if (!_isGhost &&
                media!.isMain &&
                media!.kind == ListingMediaKind.image)
              PositionedDirectional(
                top: AppSpacing.sm,
                end: AppSpacing.sm,
                child: _MainBadge(),
              ),
            if (!_isGhost)
              PositionedDirectional(
                top: AppSpacing.sm,
                start: AppSpacing.sm,
                child: _OrderingBadge(ordering: media!.ordering),
              ),
            // Spec 026 — 360°/virtual-tour mark on the thumbnail (bottom-start)
            // so the publisher can see which image is the panorama.
            if (!_isGhost && media!.isPanorama)
              PositionedDirectional(
                bottom: AppSpacing.sm,
                start: AppSpacing.sm,
                child: _PanoramaBadge(),
              ),
            // Phase 029 (F3) — "more actions" handle, shown only when drag is
            // enabled (so the long-press sheet remains reachable as fallback).
            if (!_isGhost && isEditable && dragEnabled)
              PositionedDirectional(
                bottom: AppSpacing.sm,
                end: AppSpacing.sm,
                child: _ActionsHandle(onTap: () => _openActionSheet(context)),
              ),
            if (_isGhost)
              _GhostOverlay(progress: _ghostProgress!, onDismiss: onDismiss),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_isGhost) {
      return Container(color: scheme.surfaceContainerHigh);
    }
    final m = media!;
    if (m.kind == ListingMediaKind.video) {
      // Phase 030 (W1) — show the generated poster (in listing-images) behind a
      // play-button overlay when present; otherwise fall back to the neutral
      // placeholder used before posters existed.
      final poster = m.thumbnailPath;
      final playOverlay = Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 48,
          color: poster != null
              ? scheme.onInverseSurface
              : scheme.onSurfaceVariant,
        ),
      );
      if (poster == null) {
        return Container(
          color: scheme.surfaceContainerHighest,
          child: playOverlay,
        );
      }
      final posterUrl = getIt<ListingsRepository>().getMediaPublicUrl(
        bucket: 'listing-images',
        path: poster,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: posterUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                Container(color: scheme.surfaceContainerHighest),
            errorWidget: (_, _, _) =>
                Container(color: scheme.surfaceContainerHighest),
          ),
          playOverlay,
        ],
      );
    }
    // kind=image — render via cached_network_image for re-mount reliability (R-29)
    final path = m.storagePath;
    if (path == null) {
      return Container(
        color: scheme.errorContainer,
        child: Icon(Icons.broken_image_outlined, color: scheme.error),
      );
    }
    final repository = getIt<ListingsRepository>();
    final url = repository.getMediaPublicUrl(
      bucket: 'listing-images',
      path: path,
    );
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: scheme.surfaceContainerHigh),
      errorWidget: (_, _, _) => Container(
        color: scheme.errorContainer,
        child: Icon(Icons.broken_image_outlined, color: scheme.error),
      ),
    );
  }

  Future<void> _openActionSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onSetMain != null)
                ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: Text(l10n.mediaActionSetMain),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    onSetMain!();
                  },
                ),
              // Spec 026 — (un)mark this image as a 360°/virtual-tour panorama.
              if (onTogglePanorama != null)
                ListTile(
                  leading: const Icon(Icons.threesixty),
                  title: Text(
                    // Phase 029 (F5) — softened wording: this marks an ALREADY
                    // UPLOADED ordinary photo as 360° (distinct from the new
                    // "Add 360° photo" upload CTA on the media step).
                    (media?.isPanorama ?? false)
                        ? l10n.mediaActionUnmarkExistingPanorama
                        : l10n.mediaActionMarkExistingPanorama,
                  ),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    onTogglePanorama!();
                  },
                ),
              if (onMoveUp != null)
                ListTile(
                  leading: const Icon(Icons.arrow_upward),
                  title: Text(l10n.mediaActionReorderHint),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    onMoveUp!();
                  },
                ),
              if (onMoveDown != null)
                ListTile(
                  leading: const Icon(Icons.arrow_downward),
                  title: Text(l10n.mediaActionReorderHint),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    onMoveDown!();
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(sheetCtx).colorScheme.error,
                  ),
                  title: Text(
                    l10n.mediaActionDelete,
                    style: AppTextStyles.of(sheetCtx).bodyLarge.copyWith(
                      color: Theme.of(sheetCtx).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    onDelete!();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MainBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        l10n.mediaThumbnailMainBadge,
        style: AppTextStyles.of(
          context,
        ).labelMedium.copyWith(color: scheme.onPrimary),
      ),
    );
  }
}

/// Phase 029 (F3) — small over-photo "more actions" handle. Tapping opens the
/// per-thumbnail action sheet (set main, 360°, move up/down, delete). Rendered
/// only when drag-reorder is enabled so the sheet stays reachable.
class _ActionsHandle extends StatelessWidget {
  const _ActionsHandle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.scrim.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(
            Icons.more_vert,
            size: AppSpacing.lg,
            color: scheme.onInverseSurface,
          ),
        ),
      ),
    );
  }
}

/// Spec 026 — small "360°" chip on a panorama thumbnail in the media picker.
class _PanoramaBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.threesixty,
            size: AppSpacing.md,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            l10n.mediaThumbnailPanoramaBadge,
            style: AppTextStyles.of(
              context,
            ).labelMedium.copyWith(color: scheme.onTertiaryContainer),
          ),
        ],
      ),
    );
  }
}

class _OrderingBadge extends StatelessWidget {
  const _OrderingBadge({required this.ordering});

  final int ordering;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.scrim.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Text(
        formatLocalizedNumber(ordering, Localizations.localeOf(context)),
        style: AppTextStyles.of(
          context,
        ).labelMedium.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}

class _GhostOverlay extends StatelessWidget {
  const _GhostOverlay({required this.progress, this.onDismiss});

  final MediaUploadProgress progress;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.85),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: switch (progress) {
              MediaUploadProgressIdle() ||
              MediaUploadProgressProcessing() ||
              MediaUploadProgressUploading() =>
                const CircularProgressIndicator(),
              // Phase 030 (W1) — 720p transcode in progress. Determinate ring +
              // a "compressing" caption once the first progress tick arrives.
              MediaUploadProgressCompressing(percent: final pct) => Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (pct != null) ? (pct / 100).clamp(0.0, 1.0) : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.videoCompressing,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.of(
                        context,
                      ).labelMedium.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              MediaUploadProgressError(errorKey: final key) => Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: scheme.error),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _resolveErrorKey(l10n, key),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.of(context).labelMedium.copyWith(
                        color: scheme.error,
                      ), // was fontSize:11 — labelMedium(12) is nearest token
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              MediaUploadProgressCompleted() => Icon(
                Icons.check_circle_outline,
                color: scheme.primary,
              ),
            },
          ),
          // Dismiss (X) button — shown only on error tiles. Tapping clears
          // the orphaned uploadInFlight entry so the publisher can retry by
          // re-picking from the gallery (task #30 follow-up).
          if (progress is MediaUploadProgressError && onDismiss != null)
            PositionedDirectional(
              top: AppSpacing.xs,
              end: AppSpacing.xs,
              child: Material(
                color: scheme.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDismiss,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(Icons.close, size: 18, color: scheme.error),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _resolveErrorKey(AppLocalizations l10n, String key) {
    switch (key) {
      case 'media.error.formatNotSupported':
        return l10n.mediaErrorFormatNotSupported;
      case 'media.error.imageTooLarge':
        return l10n.mediaErrorImageTooLarge;
      case 'media.error.timeout':
        return l10n.mediaErrorTimeout;
      case 'media.error.watermarkAssetMissing':
        return l10n.mediaErrorWatermarkAssetMissing;
      case 'media.error.uploadFailed':
        return l10n.mediaErrorUploadFailed;
      case 'media.error.videoFormatMustBeMp4':
        return l10n.mediaErrorVideoFormatMustBeMp4;
      case 'media.error.videoSizeExceeded':
        return l10n.mediaErrorVideoSizeExceeded;
      case 'media.cap.images10':
        return l10n.mediaCapImages10;
      case 'media.cap.videos2':
        return l10n.mediaCapVideos2;
      // Phase 029 (F5) — 360° panorama-specific errors.
      case 'media.cap.panoramas2':
        return l10n.mediaCapPanoramas2;
      case 'media.error.notEquirectangular':
        return l10n.mediaErrorNotEquirectangular;
      default:
        return l10n.mediaErrorUploadFailed;
    }
  }
}
