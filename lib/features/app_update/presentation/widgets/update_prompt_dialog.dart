import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../domain/entities/version_manifest.dart';

/// Shows the update-available prompt dialog.
///
/// Localized, Phase-2 design-token styled (no hardcoded colors or sizes).
/// Shown **once per cold start** by `app.dart` (T018 / R-211).
///
/// Behaviour:
/// - **Update** button → opens [manifest.downloadUrl] via `url_launcher`
///   (`telegram_url ?? website_url` — R-211); then dismisses the dialog.
/// - **Later** button → dismisses for the current session (no persisted state).
/// - If [manifest.downloadUrl] is null, the Update button is hidden.
Future<void> showUpdatePrompt(
  BuildContext context,
  VersionManifest manifest, {
  bool required = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) =>
        _UpdatePromptDialog(manifest: manifest, required: required),
  );
}

class _UpdatePromptDialog extends StatelessWidget {
  const _UpdatePromptDialog({required this.manifest, required this.required});

  final VersionManifest manifest;

  /// Plan A31 — below the floor: no "later", no back, the only way on is up.
  final bool required;

  @override
  Widget build(BuildContext context) {
    final loc = AppStrings.of(context).loc;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);

    final releaseNote = manifest.releaseNotes?.forLocale(locale);
    final downloadUrl = manifest.downloadUrl;

    final releaseNotesBlock = releaseNote != null && releaseNote.isNotEmpty
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.updatePromptReleaseNotesLabel,
                style: styles.labelMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(releaseNote, style: styles.bodyMedium),
            ],
          )
        : null;

    final iconBadge = Container(
      width: AppSpacing.xxxl,
      height: AppSpacing.xxxl,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        LucideIcons.circle_arrow_up,
        color: colors.primary,
        size: AppSpacing.xl,
      ),
    );

    if (required && downloadUrl != null) {
      // Plan A31 — the installed build is below min_supported_version. The
      // dialog stays up after the tap: the person leaves to install, and the
      // next launch is the new build.
      return PopScope(
        canPop: false,
        child: AlertDialog(
          icon: iconBadge,
          title: Text(loc.updatePromptTitle, style: styles.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(loc.updatePromptRequiredBody, style: styles.bodyMedium),
              if (releaseNotesBlock != null) ...[
                const SizedBox(height: AppSpacing.lg),
                releaseNotesBlock,
              ],
            ],
          ),
          actions: [
            AppButton.filledPrimary(
              label: loc.updatePromptUpdate,
              onPressed: () async {
                final uri = Uri.tryParse(downloadUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
      );
    }

    if (downloadUrl == null) {
      // No download URL in the manifest → only the "Later" dismissal exists.
      // AppDialog's fixed cancel/action pair cannot express a single-button
      // dialog, so this rare branch keeps a hand-rolled [AlertDialog] styled
      // like the AppDialog idiom (tinted glyph, token type, AppButton action).
      return AlertDialog(
        icon: iconBadge,
        title: Text(loc.updatePromptTitle, style: styles.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(loc.updatePromptBody, style: styles.bodyMedium),
            if (releaseNotesBlock != null) ...[
              const SizedBox(height: AppSpacing.lg),
              releaseNotesBlock,
            ],
          ],
        ),
        actions: [
          AppButton(
            label: loc.updatePromptLater,
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      );
    }

    return AppDialog(
      icon: LucideIcons.circle_arrow_up,
      title: loc.updatePromptTitle,
      message: loc.updatePromptBody,
      content: releaseNotesBlock,
      cancelLabel: loc.updatePromptLater,
      actionLabel: loc.updatePromptUpdate,
      onAction: () async {
        Navigator.of(context).pop();
        final uri = Uri.tryParse(downloadUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
