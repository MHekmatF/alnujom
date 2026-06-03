import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/spacing.dart';
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
  VersionManifest manifest,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _UpdatePromptDialog(manifest: manifest),
  );
}

class _UpdatePromptDialog extends StatelessWidget {
  const _UpdatePromptDialog({required this.manifest});

  final VersionManifest manifest;

  @override
  Widget build(BuildContext context) {
    final loc = AppStrings.of(context).loc;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    final releaseNote = manifest.releaseNotes?.forLocale(locale);
    final downloadUrl = manifest.downloadUrl;

    return AlertDialog(
      title: Text(loc.updatePromptTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.updatePromptBody),
          if (releaseNote != null && releaseNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              loc.updatePromptReleaseNotesLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              releaseNote,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.updatePromptLater),
        ),
        if (downloadUrl != null)
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final uri = Uri.tryParse(downloadUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(loc.updatePromptUpdate),
          ),
      ],
    );
  }
}
