import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/spacing.dart';

/// Phase 23 (FC / T022) — a single tappable support-contact channel row
/// (phone / WhatsApp / email) used by both [MaintenanceScreen] and
/// [AboutSupportPage].
///
/// Callers render this ONLY for channels that are set (non-null/non-empty), so
/// the screens never surface an empty or broken affordance (FR-013). The row
/// itself does not null-check — that filtering belongs to the caller.
class SupportContactRow extends StatelessWidget {
  const SupportContactRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.launchUri,
  });

  /// Builds a phone-call row (`tel:` scheme).
  factory SupportContactRow.phone({
    required String label,
    required String phone,
  }) {
    return SupportContactRow(
      icon: Icons.phone_outlined,
      label: label,
      value: phone,
      launchUri: Uri.parse('tel:$phone'),
    );
  }

  /// Builds a WhatsApp row (`https://wa.me/<digits>`), stripping the leading `+`.
  factory SupportContactRow.whatsapp({
    required String label,
    required String whatsapp,
  }) {
    final digits = whatsapp.replaceAll('+', '').trim();
    return SupportContactRow(
      icon: Icons.chat_outlined,
      label: label,
      value: whatsapp,
      launchUri: Uri.parse('https://wa.me/$digits'),
    );
  }

  /// Builds an email row (`mailto:` scheme).
  factory SupportContactRow.email({
    required String label,
    required String email,
  }) {
    return SupportContactRow(
      icon: Icons.email_outlined,
      label: label,
      value: email,
      launchUri: Uri.parse('mailto:$email'),
    );
  }

  final IconData icon;
  final String label;
  final String value;
  final Uri launchUri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.open_in_new, size: AppSpacing.lg),
      onTap: () =>
          unawaited(launchUrl(launchUri, mode: LaunchMode.externalApplication)),
    );
  }
}
