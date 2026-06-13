import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
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
  static const _panoramaCap = 2;

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
            .where((m) => m.kind == ListingMediaKind.image && !m.isPanorama)
            .length;
        final videoCount = state.media
            .where((m) => m.kind == ListingMediaKind.video)
            .length;
        // Phase 029 (F5) — a panorama row is an equirectangular image whose
        // free-text rawKind is 'panorama'. Count those separately so the 360°
        // CTA caps at 2 (mirrors the video cap UX).
        final panoramaCount = state.media.where((m) => m.isPanorama).length;
        final imagesFull = imageCount >= _imageCap;
        final videosFull = videoCount >= _videoCap;
        final panoramasFull = panoramaCount >= _panoramaCap;

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
                panoramasFull: panoramasFull,
                l10n: l10n,
              ),
              const SizedBox(height: AppSpacing.md),
              _MediaTipsStrip(imageCount: imageCount, l10n: l10n),
              const SizedBox(height: AppSpacing.lg),
            ],
            const MediaPicker(),
          ],
        );
      },
    );
  }
}

/// Phase 029 (F3) — informational tips strip on the media step. Shows the
/// current photo count and a lighting/quality hint. Purely informational — no
/// actions, no state.
class _MediaTipsStrip extends StatelessWidget {
  const _MediaTipsStrip({required this.imageCount, required this.l10n});

  final int imageCount;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: appRadius(AppRadii.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.lightbulb, size: AppSpacing.lg, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.mediaTipsPhotoCount(imageCount),
                  style: styles.labelLarge.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.mediaTipsLightingHint,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
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
    required this.panoramasFull,
    required this.l10n,
  });

  final bool imagesFull;
  final bool videosFull;
  final bool panoramasFull;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
        ),
        const SizedBox(height: AppSpacing.md),
        // Phase 029 (F5) — third CTA: "Add 360° photo". A help (?) button next
        // to it opens a bottom sheet explaining how to capture one.
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.mediaAddPanorama,
                icon: LucideIcons.rotate_3d,
                variant: AppButtonVariant.tonal,
                expanded: true,
                onPressed: panoramasFull ? null : () => _pickPanorama(context),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton.iconButton(
              icon: LucideIcons.circle_question_mark,
              onPressed: () => _showPanoramaHelp(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickPanorama(BuildContext context) async {
    final bloc = context.read<ListingFormBloc>();
    final l10n = AppLocalizations.of(context)!;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        if (!context.mounted) return;
        AppToast.show(
          context,
          l10n.mediaErrorGalleryPermissionDenied,
          variant: AppToastVariant.warning,
          action: SnackBarAction(
            label: l10n.mediaActionOpenSettings,
            onPressed: AndroidSettingsChannel.openAppSettings,
          ),
        );
        return;
      }
      bloc.add(PanoramaPicked(file));
    } catch (_) {
      if (!context.mounted) return;
      AppToast.error(context, l10n.mediaErrorUploadFailed);
    }
  }

  Future<void> _showPanoramaHelp(BuildContext context) {
    return AppBottomSheet.show<void>(
      context,
      child: _PanoramaHelpSheet(l10n: l10n),
    );
  }

  Future<void> _pickImages(BuildContext context) async {
    final bloc = context.read<ListingFormBloc>();
    final isRtl = Directionality.of(context) == TextDirection.rtl;
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
        if (!context.mounted) return;
        AppToast.show(
          context,
          l10n.mediaErrorGalleryPermissionDenied,
          variant: AppToastVariant.warning,
          action: SnackBarAction(
            label: l10n.mediaActionOpenSettings,
            onPressed: AndroidSettingsChannel.openAppSettings,
          ),
        );
        return;
      }
      bloc.add(MediaPicked(files, isRtl: isRtl));
    } catch (_) {
      if (!context.mounted) return;
      AppToast.error(context, l10n.mediaErrorUploadFailed);
    }
  }

  Future<void> _pickVideo(BuildContext context) async {
    final bloc = context.read<ListingFormBloc>();
    final l10n = AppLocalizations.of(context)!;
    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(source: ImageSource.gallery);
      if (file == null) {
        if (!context.mounted) return;
        AppToast.show(
          context,
          l10n.mediaErrorGalleryPermissionDenied,
          variant: AppToastVariant.warning,
          action: SnackBarAction(
            label: l10n.mediaActionOpenSettings,
            onPressed: AndroidSettingsChannel.openAppSettings,
          ),
        );
        return;
      }
      bloc.add(VideoPicked(file));
    } catch (_) {
      if (!context.mounted) return;
      AppToast.error(context, l10n.mediaErrorUploadFailed);
    }
  }
}

/// Phase 029 (F5) — bottom-sheet help explaining how to capture a 360°
/// equirectangular photo with a free app, with a Play Store link to Google
/// Street View. Informational only; opening it does not change form state.
class _PanoramaHelpSheet extends StatelessWidget {
  const _PanoramaHelpSheet({required this.l10n});

  final AppLocalizations l10n;

  // Google Street View on the Play Store — the most widely available free 360°
  // capture app in Syria.
  static final Uri _streetViewUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.google.android.street',
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.rotate_3d, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.mediaPanoramaHelpTitle,
                style: styles.titleMedium.copyWith(color: colors.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.mediaPanoramaHelpIntro,
          style: styles.bodyMedium.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        _HelpStep(index: 1, text: l10n.mediaPanoramaHelpStep1),
        _HelpStep(index: 2, text: l10n.mediaPanoramaHelpStep2),
        _HelpStep(index: 3, text: l10n.mediaPanoramaHelpStep3),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.mediaPanoramaHelpGetApp,
          icon: LucideIcons.external_link,
          variant: AppButtonVariant.outlined,
          expanded: true,
          onPressed: () => _openStreetView(context),
        ),
      ],
    );
  }

  Future<void> _openStreetView(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (await canLaunchUrl(_streetViewUri)) {
      await launchUrl(_streetViewUri, mode: LaunchMode.externalApplication);
    } else {
      messenger.hideCurrentSnackBar();
      if (!context.mounted) return;
      AppToast.error(context, l10n.mediaErrorUploadFailed);
    }
  }
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.xl,
            height: AppSpacing.xl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              NumberFormat.decimalPattern(locale).format(index),
              style: styles.labelMedium.copyWith(color: colors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: styles.bodyMedium.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
