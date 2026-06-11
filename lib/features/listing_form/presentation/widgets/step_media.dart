import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart';
import '../../domain/entities/listing_media.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import '../util/android_settings_channel.dart';
import 'media_picker.dart';
import 'step_section.dart';

/// Phase 11 — step 6 (Media) of the seven-step listing form.
///
/// Replaces Phase 10's `step_media_placeholder.dart` no-op. Renders:
/// 1. A read-only banner when the parent listing is not editable
///    (`status NOT IN ('draft', 'rejected')`).
/// 2. Two upload-affordance CTAs: "Add images" (disabled at the 10-image cap)
///    and "Add video" (disabled at the 2-video cap).
/// 3. The [MediaPicker] reorderable grid below — only shown in editable mode.
///
/// Per Q2=D: there is NO "Add external link" CTA in Phase 11.
/// Per Constitution IX: no `package:supabase_flutter` imports — storage SDK
/// calls live in the datasource; this widget dispatches BLoC events.
class StepMedia extends StatelessWidget {
  const StepMedia({super.key});

  static const _imageCap = 10;
  static const _videoCap = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();

        final isEditable =
            listing.status == ListingStatus.draft ||
            listing.status == ListingStatus.rejected;

        final imageCount = state.media
            .where((m) => m.kind == ListingMediaKind.image)
            .length;
        final videoCount = state.media
            .where((m) => m.kind == ListingMediaKind.video)
            .length;
        final imagesFull = imageCount >= _imageCap;
        final videosFull = videoCount >= _videoCap;

        return StepSection(
          icon: Icons.photo_library_outlined,
          title: l10n.listingFormStepMediaTitle,
          subtitle: l10n.listingFormStepMediaSubtitle,
          children: [
            if (!isEditable) _ReadOnlyBanner(l10n: l10n),
            if (isEditable) ...[
              _AddAffordances(
                imagesFull: imagesFull,
                videosFull: videosFull,
                l10n: l10n,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const MediaPicker(),
          ],
        );
      },
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.md),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: colors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.mediaReadOnlyPendingOrApproved,
              style: styles.bodyMedium.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAffordances extends StatelessWidget {
  const _AddAffordances({
    required this.imagesFull,
    required this.videosFull,
    required this.l10n,
  });

  final bool imagesFull;
  final bool videosFull;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: l10n.mediaAddImages,
            icon: Icons.add_photo_alternate_outlined,
            variant: AppButtonVariant.tonal,
            expanded: true,
            onPressed: imagesFull ? null : () => _pickImages(context),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppButton(
            label: l10n.mediaAddVideo,
            icon: Icons.videocam_outlined,
            variant: AppButtonVariant.tonal,
            expanded: true,
            onPressed: videosFull ? null : () => _pickVideo(context),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImages(BuildContext context) async {
    final bloc = context.read<ListingFormBloc>();
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage();
      if (files.isEmpty) {
        // Empty result — either the publisher cancelled OR the platform
        // surfaced a permission denial. There is no way to distinguish
        // reliably across image_picker versions; surface a non-fatal hint
        // with the Open-settings CTA so the publisher can recover if it
        // was a denial.
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.mediaErrorGalleryPermissionDenied),
            action: SnackBarAction(
              label: l10n.mediaActionOpenSettings,
              onPressed: AndroidSettingsChannel.openAppSettings,
            ),
          ),
        );
        return;
      }
      bloc.add(MediaPicked(files, isRtl: isRtl));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.mediaErrorUploadFailed)),
      );
    }
  }

  Future<void> _pickVideo(BuildContext context) async {
    final bloc = context.read<ListingFormBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(source: ImageSource.gallery);
      if (file == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.mediaErrorGalleryPermissionDenied),
            action: SnackBarAction(
              label: l10n.mediaActionOpenSettings,
              onPressed: AndroidSettingsChannel.openAppSettings,
            ),
          ),
        );
        return;
      }
      bloc.add(VideoPicked(file));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.mediaErrorUploadFailed)),
      );
    }
  }
}
