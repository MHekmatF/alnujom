import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/agent_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../features/chat/domain/usecases/get_or_create_conversation.dart';
import '../../../../features/chat/presentation/bloc/chat_thread_cubit.dart';
import '../../../../features/chat/presentation/pages/chat_thread_page.dart';
import '../../../../features/inquiries/domain/entities/lead_event_type.dart';
import '../../../../features/inquiries/domain/usecases/record_lead_event.dart';
import '../../../../features/inquiries/presentation/bloc/contact_cta_cubit.dart';
import '../../../../features/inquiries/presentation/sheets/inquiry_form_sheet.dart';
import '../../../../features/listing_form/domain/entities/listing.dart';
import '../../../../features/reviews/presentation/widgets/seller_trust_summary.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 16 (spec/016-contact-inquiries) — Contact CTA block.
///
/// Premium uplift v2 — restyled into a richer agent/agency contact card
/// ([AgentCard]): a leading avatar (agency logo or publisher initials), the
/// agent/agency [contactName] with an optional verified check + [subtitle], and
/// a bottom actions row of Call / WhatsApp / Send-inquiry buttons. The Phase-16
/// handlers + visibility logic (Call only when phone is set; WhatsApp always
/// rendered, disabled when no number; self-contact collapse) are preserved
/// verbatim — only the presentation changed.
///
/// FR-001d: self-contact guard — when the signed-in user IS the publisher the
/// widget collapses to `SizedBox.shrink()`.
class ContactBlock extends StatelessWidget {
  const ContactBlock({
    super.key,
    required this.listing,
    this.contactName,
    this.subtitle,
    this.logoUrl,
    this.verified = false,
  });

  final Listing listing;

  /// Display name for the contact card header (agency or publisher name). When
  /// null/empty the card omits the agent header and shows the actions alone.
  final String? contactName;

  /// Optional secondary line (e.g. "Verified agency" / role).
  final String? subtitle;

  /// Resolved public logo URL for the avatar (agency logo). Null → initials.
  final String? logoUrl;

  /// Renders a green verified check beside the name when true.
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ContactCtaCubit>(
      create: (_) => getIt<ContactCtaCubit>(param1: listing),
      child: BlocBuilder<ContactCtaCubit, ContactCtaState>(
        builder: (context, state) {
          if (state.isSelfContact) return const SizedBox.shrink();

          final l10n = AppLocalizations.of(context)!;
          final colors = AppColors.of(context);
          final styles = AppTextStyles.of(context);

          // Secondary actions (Call + WhatsApp) share a row; each can shrink.
          final secondary = <Widget>[
            // Call CTA — visible only when phone is set (FR-001a).
            if (state.showCall)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _onCallPressed(context, state.phone!),
                  icon: const Icon(Icons.phone_outlined),
                  label: Text(
                    l10n.cta_call,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // WhatsApp CTA — always rendered; disabled w/o number (Q1=B-refined).
            if (state.showWhatsApp)
              Expanded(
                child: Tooltip(
                  message: state.whatsappEnabled
                      ? ''
                      : l10n.contact_whatsapp_disabled_tooltip,
                  child: OutlinedButton.icon(
                    onPressed: state.whatsappEnabled
                        ? () => _onWhatsAppPressed(context, state.whatsapp!)
                        : null,
                    icon: const Icon(Icons.chat_outlined),
                    label: Text(
                      l10n.cta_whatsapp,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            // In-app chat CTA — opens (or creates) a conversation with the
            // publisher. The block is hidden for self-contact, so no self-msg.
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _onMessagePressed(context),
                icon: const Icon(Icons.forum_outlined),
                label: Text(
                  l10n.chatContactAction,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ];

          // Primary action — full-width Send-inquiry (always present for
          // non-self-contact per FR-001c).
          final primary = state.showInquiry
              ? AppButton(
                  label: l10n.cta_send_inquiry,
                  variant: AppButtonVariant.filledPrimary,
                  icon: Icons.email_outlined,
                  expanded: true,
                  onPressed: () => _onSendInquiryPressed(context),
                )
              : null;

          // Stack the seller-trust summary (rating + response badge) above the
          // primary inquiry over the Call/WhatsApp pair. The summary reads the
          // page-provided SellerTrustCubit and collapses when no data.
          final actionStack = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SellerTrustSummary(),
              if (primary != null) primary,
              if (primary != null && secondary.isNotEmpty)
                const SizedBox(height: AppSpacing.sm),
              if (secondary.isNotEmpty) Row(children: _interspersed(secondary)),
            ],
          );

          // When we have a contact name, present the full agent card. The
          // AgentCard lays actions in a single Row, so we pass one full-width
          // child carrying our vertical action stack. Otherwise fall back to a
          // titled actions column (behavior-preserving).
          if (contactName != null && contactName!.trim().isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.contact_section_title,
                  style: styles.titleMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AgentCard(
                  name: contactName!.trim(),
                  logoUrl: logoUrl,
                  verified: verified,
                  subtitle: subtitle,
                  actions: [Expanded(child: actionStack)],
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.contact_section_title,
                style: styles.titleMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              actionStack,
            ],
          );
        },
      ),
    );
  }

  static List<Widget> _interspersed(List<Widget> actions) {
    final out = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) out.add(const SizedBox(width: AppSpacing.sm));
      out.add(actions[i]);
    }
    return out;
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

  Future<void> _onWhatsAppPressed(BuildContext context, String whatsapp) async {
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

  /// In-app chat entry. Anonymous → sign-in snackbar. Signed-in → open (or
  /// create) the conversation for this listing, then push the thread page.
  Future<void> _onMessagePressed(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (getIt<AuthBloc>().state is! Authenticated) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.chatSignInPrompt)),
      );
      return;
    }

    final result = await getIt<GetOrCreateConversation>()(listing.id);
    if (!context.mounted) return;

    switch (result) {
      case Success(:final value):
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider<ChatThreadCubit>(
              create: (_) => getIt<ChatThreadCubit>(),
              child: ChatThreadPage(
                conversationId: value,
                listingTitle: listing.title,
              ),
            ),
          ),
        );
      case FailureResult():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.chatOpenError)),
        );
    }
  }
}
