import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
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
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
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
       onDelete = null,
       onMoveUp = null,
       onMoveDown = null,
       _ghostProgress = progress;

  final ListingMedia? media;
  final bool isEditable;
  final VoidCallback? onSetMain;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDismiss;
  final MediaUploadProgress? _ghostProgress;

  bool get _isGhost => _ghostProgress != null;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: GestureDetector(
        onLongPress: (_isGhost || !isEditable)
            ? null
            : () => _openActionSheet(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(context),
            if (!_isGhost && media!.isMain && media!.kind == ListingMediaKind.image)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: _MainBadge(),
              ),
            if (!_isGhost)
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: _OrderingBadge(ordering: media!.ordering),
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
      return Container(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.play_circle_outline,
            size: 48,
            color: scheme.onSurfaceVariant,
          ),
        ),
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
                    style: TextStyle(
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
        style: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
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
        '$ordering',
        style: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
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
                      style: TextStyle(color: scheme.error, fontSize: 11),
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
                    padding: const EdgeInsets.all(2),
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
      default:
        return l10n.mediaErrorUploadFailed;
    }
  }
}
