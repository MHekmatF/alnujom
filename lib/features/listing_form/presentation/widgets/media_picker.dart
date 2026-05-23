import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
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
/// Reorder strategy: Phase 11 v1 uses the long-press action sheet's
/// "Move up" / "Move down" actions to re-sequence `ordering`. Drag-reorder
/// in a 3-column grid is forward-stated to a future spec (no
/// `reorderable_grid_view` package is in pubspec.yaml and adding one is
/// out of R-22 scope).
class MediaPicker extends StatelessWidget {
  const MediaPicker({super.key});

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      buildWhen: (prev, next) =>
          prev.media != next.media ||
          prev.uploadInFlight != next.uploadInFlight ||
          prev.draftListing?.status != next.draftListing?.status,
      builder: (context, state) {
        final media = state.media;
        final inFlightEntries = state.uploadInFlight.entries.toList();
        final isEditable =
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
              return MediaThumbnail(
                media: m,
                isEditable: isEditable,
                onSetMain: m.kind == ListingMediaKind.image
                    ? () => context
                          .read<ListingFormBloc>()
                          .add(MediaSetMain(m.id))
                    : null,
                onDelete: () => _confirmDelete(context, m),
                onMoveUp: index > 0
                    ? () => _moveTo(context, media, index, index - 1)
                    : null,
                onMoveDown: index < media.length - 1
                    ? () => _moveTo(context, media, index, index + 1)
                    : null,
              );
            }
            final ghost = inFlightEntries[index - media.length];
            return MediaThumbnail.ghost(progress: ghost.value);
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
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.mediaActionDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
            ),
            child: Text(l10n.mediaActionDelete),
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.mediaActionReorderHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
