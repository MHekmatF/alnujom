import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../features/inquiries/domain/entities/lead_event_type.dart';
import '../../../../features/inquiries/domain/usecases/record_lead_event.dart';
import '../../../../features/inquiries/presentation/bloc/contact_cta_cubit.dart';
import '../../../../features/inquiries/presentation/sheets/inquiry_form_sheet.dart';
import '../../../../features/listing_form/domain/entities/listing.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 16 (spec/016-contact-inquiries) — Contact CTA block (rewired).
///
/// Constructor now requires [listing] so the [ContactCtaCubit] (factory-scoped)
/// can compute visibility flags from `phone`, `whatsapp`, and `publisherUserId`.
///
/// Three CTAs preserved verbatim from Phase 13 (Call / WhatsApp / Send Inquiry —
/// same icons, labels, ordering). The Phase 13 `_showComingSoon` stubs are
/// replaced with real handlers per FR-002..FR-005.
///
/// FR-001b (Q1=B-refined): WhatsApp button always renders when `showWhatsApp`
/// is true; `onPressed` is null when `!whatsappEnabled` (render-but-disabled)
/// and a Tooltip shows `contact_whatsapp_disabled_tooltip`.
///
/// FR-001d: self-contact guard — when the signed-in user IS the publisher,
/// the widget collapses to `SizedBox.shrink()`.
class ContactBlock extends StatelessWidget {
  const ContactBlock({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ContactCtaCubit>(
      create: (_) => getIt<ContactCtaCubit>(param1: listing),
      child: BlocBuilder<ContactCtaCubit, ContactCtaState>(
        builder: (context, state) {
          if (state.isSelfContact) return const SizedBox.shrink();

          final l10n = AppLocalizations.of(context)!;
          final theme = Theme.of(context);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.contact_section_title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Call CTA — visible only when phone is set (FR-001a).
              if (state.showCall) ...[
                OutlinedButton.icon(
                  onPressed: () => _onCallPressed(context, state.phone!),
                  icon: const Icon(Icons.phone_outlined),
                  label: Text(l10n.cta_call),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              // WhatsApp CTA — always rendered; disabled when no number (Q1=B-refined).
              if (state.showWhatsApp) ...[
                Tooltip(
                  message: state.whatsappEnabled
                      ? ''
                      : l10n.contact_whatsapp_disabled_tooltip,
                  child: OutlinedButton.icon(
                    onPressed: state.whatsappEnabled
                        ? () =>
                            _onWhatsAppPressed(context, state.whatsapp!)
                        : null,
                    icon: const Icon(Icons.chat_outlined),
                    label: Text(l10n.cta_whatsapp),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              // Send Inquiry CTA — always available for non-self-contact (FR-001c).
              if (state.showInquiry)
                OutlinedButton.icon(
                  onPressed: () => _onSendInquiryPressed(context),
                  icon: const Icon(Icons.email_outlined),
                  label: Text(l10n.cta_send_inquiry),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onCallPressed(BuildContext context, String phone) async {
    await getIt<RecordLeadEvent>()(
      listingId: listing.id,
      eventType: LeadEventType.phoneRevealed,
    );
    final launched = await launchUrl(Uri.parse('tel:$phone'));
    if (!launched && context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.contact_dialer_unavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onWhatsAppPressed(
    BuildContext context,
    String whatsapp,
  ) async {
    await getIt<RecordLeadEvent>()(
      listingId: listing.id,
      eventType: LeadEventType.whatsappClicked,
    );
    final e164NoPlus = whatsapp.replaceAll('+', '');
    final launched = await launchUrl(
      Uri.parse('https://wa.me/$e164NoPlus'),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.contact_whatsapp_app_unavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onSendInquiryPressed(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => InquiryFormSheet(listingId: listing.id),
    );
  }
}
