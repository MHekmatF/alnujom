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
