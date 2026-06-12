import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';

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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return InkWell(
      borderRadius: appRadius(AppRadii.md),
      onTap: () =>
          unawaited(launchUrl(launchUri, mode: LaunchMode.externalApplication)),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            // Leading icon in a soft brand-tinted square (profile-row idiom).
            Container(
              width: AppSpacing.xxl + AppSpacing.sm,
              height: AppSpacing.xxl + AppSpacing.sm,
              alignment: AlignmentDirectional.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: appRadius(AppRadii.md),
              ),
              child: Icon(icon, color: colors.primary, size: AppSpacing.xl),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: styles.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    value,
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.open_in_new,
              size: AppSpacing.lg,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
