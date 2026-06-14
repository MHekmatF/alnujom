import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart';
import '../../domain/entities/listing_media.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import 'media_thumbnail.dart';

/// Phase 11 — MediaPicker reorderable 3-column grid.
///
/// Per contracts/media-picker-pages.md. Renders every `state.media` row as a
/// [MediaThumbnail]. In-flight uploads (rows that have not yet committed)
/// surface as ghost tiles at the end with a progress / error overlay; their
/// keys come from the `state.uploadInFlight` map.
///
/// Reorder strategy (Phase 029 F3): drag-reorder via [LongPressDraggable] +
/// [DragTarget] over the existing [GridView] — NO new package. Long-press a
/// committed tile to lift it, then drop it onto another tile to re-sequence;
/// on drop the EXISTING [MediaReordered] event fires (its contract and the
/// reorder RPC are unchanged). The per-thumbnail action sheet (set main, 360°,
/// move up / move down, delete) stays reachable via the tile's "more actions"
/// handle as the accessibility fallback, since the long-press gesture is now
/// owned by the drag recognizer.
class MediaPicker extends StatelessWidget {
  const MediaPicker({super.key});

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      buildWhen: (prev, next) =>
          prev.media != next.media ||
          prev.uploadInFlight != next.uploadInFlight ||
          prev.isRevision != next.isRevision ||
          prev.draftListing?.status != next.draftListing?.status,
      builder: (context, state) {
        final media = state.media;
        final inFlightEntries = state.uploadInFlight.entries.toList();
        // Phase 031 (WS-B) — a stay-live revision edits an APPROVED listing, so
        // the status gate alone would lock the picker; treat revision mode as
        // editable (its media edits operate on the staged manifest, not live
        // listing_media rows).
        final isEditable =
            state.isRevision ||
            state.draftListing?.status == ListingStatus.draft ||
            state.draftListing?.status == ListingStatus.rejected;

        if (media.isEmpty && inFlightEntries.isEmpty) {
          return _EmptyState(l10n: AppLocalizations.of(context)!);
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: media.length + inFlightEntries.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (index < media.length) {
              final m = media[index];
              final thumbnail = MediaThumbnail(
                media: m,
                isEditable: isEditable,
                // Phase 029 (F3) — drag-reorder is the primary gesture in
                // editable mode, so the tile surfaces its action sheet via the
                // "more actions" handle instead of its own long-press.
                dragEnabled: isEditable,
                onSetMain: m.kind == ListingMediaKind.image
                    ? () => context.read<ListingFormBloc>().add(
                        MediaSetMain(m.id),
                      )
                    : null,
                // Spec 026 — 360°/virtual-tour toggle (image rows only; a
                // panorama is an equirectangular image). Editable drafts only.
                onTogglePanorama:
                    (isEditable && m.kind == ListingMediaKind.image)
                    ? () => context.read<ListingFormBloc>().add(
                        MediaSetPanorama(m.id, makePanorama: !m.isPanorama),
                      )
                    : null,
                onDelete: () => _confirmDelete(context, m),
                onMoveUp: index > 0
                    ? () => _moveTo(context, media, index, index - 1)
                    : null,
                onMoveDown: index < media.length - 1
                    ? () => _moveTo(context, media, index, index + 1)
                    : null,
              );
              if (!isEditable) return thumbnail;
              return _DraggableMediaTile(
                media: m,
                fromIndex: index,
                onReorderTo: (from, to) => _moveTo(context, media, from, to),
                child: thumbnail,
              );
            }
            final ghost = inFlightEntries[index - media.length];
            return MediaThumbnail.ghost(
              progress: ghost.value,
              onDismiss: ghost.value is MediaUploadProgressError
                  ? () => context.read<ListingFormBloc>().add(
                      MediaUploadDismissed(ghost.key),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  void _moveTo(
    BuildContext context,
    List<ListingMedia> media,
    int from,
    int to,
  ) {
    if (from == to) return;
    final reordered = List<ListingMedia>.from(media);
    final picked = reordered.removeAt(from);
    reordered.insert(to, picked);
    final newOrder = reordered.map((m) => m.id).toList();
    context.read<ListingFormBloc>().add(MediaReordered(newOrder));
  }

  Future<void> _confirmDelete(BuildContext context, ListingMedia m) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AppDialog(
        title: l10n.mediaActionDelete,
        icon: LucideIcons.trash_2,
        variant: AppDialogVariant.destructive,
        actionLabel: l10n.mediaActionDelete,
        cancelLabel: l10n.actionCancel,
        onAction: () => Navigator.of(dialogCtx).pop(true),
      ),
    );
    if (confirmed == true) {
      if (!context.mounted) return;
      context.read<ListingFormBloc>().add(MediaDeleted(m.id));
      messenger.hideCurrentSnackBar();
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.md),
      ),
      child: Column(
        children: [
          Icon(
            LucideIcons.image,
            size: AppSpacing.xxxl,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.mediaActionReorderHint,
            textAlign: TextAlign.center,
            style: styles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Phase 029 (F3) — wraps a [MediaThumbnail] in a [LongPressDraggable] (lift on
/// long-press) and a [DragTarget] (drop zone). On a drop, calls [onReorderTo]
/// with the source and destination grid indices, which dispatches the EXISTING
/// [MediaReordered] event. NO new package — pure Flutter drag widgets over the
/// existing [GridView].
class _DraggableMediaTile extends StatelessWidget {
  const _DraggableMediaTile({
    required this.media,
    required this.fromIndex,
    required this.onReorderTo,
    required this.child,
  });

  final ListingMedia media;
  final int fromIndex;
  final void Function(int from, int to) onReorderTo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != fromIndex,
      onAcceptWithDetails: (details) => onReorderTo(details.data, fromIndex),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return LongPressDraggable<int>(
          data: fromIndex,
          // The dragged proxy floats under the finger; keep it compact.
          feedback: Opacity(
            opacity: 0.9,
            child: SizedBox(
              width: AppSpacing.xxxl * 2,
              height: AppSpacing.xxxl * 2,
              child: ClipRRect(
                borderRadius: appRadius(AppRadii.md),
                child: child,
              ),
            ),
          ),
          // The original cell dims while a drag is in flight.
          childWhenDragging: Opacity(opacity: 0.35, child: child),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: appRadius(AppRadii.md),
              border: hovering
                  ? Border.all(color: colors.primary, width: 2)
                  : null,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
