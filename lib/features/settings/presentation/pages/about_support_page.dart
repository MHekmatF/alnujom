import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/support_contact.dart';
import '../bloc/app_settings_cubit.dart';
import '../widgets/support_contact_row.dart';

/// Phase 23 (FC / T022) — the public about/support surface (FR-013).
///
/// Renders the configured [SupportContact] channels and the `terms_url` /
/// `privacy_url` links, OMITTING any that are unset so the page never shows a
/// broken link or an empty card. Reads the snapshot from [AppSettingsCubit]
/// (already loaded at app-start / resume).
class AboutSupportPage extends StatelessWidget {
  const AboutSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about_title)),
      body: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, state) {
          final settings = state.settings;
          final contact = settings.supportContact;
          final hasLinks =
              _hasAny(settings.termsUrl) || _hasAny(settings.privacyUrl);
          final hasAnything = contact.hasAny || hasLinks;

          if (!hasAnything) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  l10n.about_no_info,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (contact.hasAny) ...[
                Text(
                  l10n.about_support_heading,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ..._buildContactRows(l10n, contact),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (hasLinks) ...[
                Text(
                  l10n.about_legal_heading,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (_hasAny(settings.termsUrl))
                  _LinkTile(
                    icon: Icons.description_outlined,
                    label: l10n.about_terms,
                    url: settings.termsUrl!,
                  ),
                if (_hasAny(settings.privacyUrl))
                  _LinkTile(
                    icon: Icons.privacy_tip_outlined,
                    label: l10n.about_privacy,
                    url: settings.privacyUrl!,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  static bool _hasAny(String? value) => value != null && value.isNotEmpty;

  List<Widget> _buildContactRows(
    AppLocalizations l10n,
    SupportContact contact,
  ) {
    final rows = <Widget>[];
    final phone = contact.phone;
    final whatsapp = contact.whatsapp;
    final email = contact.email;
    if (_hasAny(phone)) {
      rows.add(
        SupportContactRow.phone(
          label: l10n.support_channel_phone,
          phone: phone!,
        ),
      );
    }
    if (_hasAny(whatsapp)) {
      rows.add(
        SupportContactRow.whatsapp(
          label: l10n.support_channel_whatsapp,
          whatsapp: whatsapp!,
        ),
      );
    }
    if (_hasAny(email)) {
      rows.add(
        SupportContactRow.email(
          label: l10n.support_channel_email,
          email: email!,
        ),
      );
    }
    return rows;
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: theme.textTheme.bodyMedium),
      trailing: const Icon(Icons.open_in_new, size: AppSpacing.lg),
      onTap: () {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        }
      },
    );
  }
}
