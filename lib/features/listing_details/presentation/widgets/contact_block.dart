import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 13 (spec/013-home-and-details) — Contact CTA block.
///
/// Three Q2=A stub CTAs (Call / WhatsApp / Send inquiry). All taps show a
/// floating Coming-soon snackbar; NO `url_launcher` calls (tel: / wa.me/)
/// per Q2=A + contracts/phase13-cta-stub-treatment.md.
///
/// Phase 16 will replace these stubs with working `tel:` + `wa.me/` launchers
/// + the inquiry form + `record_lead_event` Edge Function.
class ContactBlock extends StatelessWidget {
  const ContactBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.cta_call,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Call CTA
        OutlinedButton.icon(
          onPressed: () =>
              _showComingSoon(context, l10n.contact_call_coming_soon),
          icon: const Icon(Icons.phone_outlined),
          label: Text(l10n.cta_call),
        ),
        const SizedBox(height: AppSpacing.sm),
        // WhatsApp CTA
        OutlinedButton.icon(
          onPressed: () =>
              _showComingSoon(context, l10n.contact_whatsapp_coming_soon),
          icon: const Icon(Icons.chat_outlined),
          label: Text(l10n.cta_whatsapp),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Send Inquiry CTA
        OutlinedButton.icon(
          onPressed: () =>
              _showComingSoon(context, l10n.contact_inquiry_coming_soon),
          icon: const Icon(Icons.email_outlined),
          label: Text(l10n.cta_send_inquiry),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
