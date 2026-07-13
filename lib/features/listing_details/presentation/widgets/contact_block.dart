import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/agent_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../features/inquiries/presentation/bloc/contact_cta_cubit.dart';
import '../../../../features/listing_form/domain/entities/listing.dart';
import '../../../../features/reviews/presentation/widgets/seller_trust_summary.dart';
import '../../../../l10n/app_localizations.dart';
import 'contact_actions.dart';

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
/// Phase 28 — the WhatsApp CTA is promoted to the MOST prominent contact
/// action: a full-width brand-green [AppButton] at the top of the action
/// stack, opening `wa.me` with a localized pre-filled message (listing title +
/// canonical link). No sticky/pinned bottom bar — the CTA lives inline in the
/// contact card.
///
/// Phase 35 (035-redesign-ground-up) craft pass — per the approved mockup,
/// exactly TWO high-emphasis actions remain: WhatsApp (green fill) + Call
/// (outlined) side by side; Send-inquiry / Request-viewing / Message are
/// demoted to quiet small text buttons in a row beneath. All handlers,
/// visibility rules, and lead-event analytics are unchanged.
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
    this.showPrimaryActions = true,
  });

  final Listing listing;

  /// When false the inline card drops its high-emphasis اتصال / واتساب pair
  /// (the DC sticky bottom bar owns them), keeping only the agent header, the
  /// trust summary, and the quiet secondary actions.
  final bool showPrimaryActions;

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

          // Approved mockup: exactly TWO high-emphasis contact actions —
          // WhatsApp (brand-green fill) + Call (outlined), side by side.
          // WhatsApp keeps the Phase-28 pre-filled message and its
          // disabled-without-number tooltip (Q1=B-refined preserved
          // verbatim); Call keeps FR-001a visibility (only when phone set).
          final primaryButtons = <Widget>[
            if (showPrimaryActions && state.showWhatsApp)
              Expanded(
                child: Tooltip(
                  message: state.whatsappEnabled
                      ? ''
                      : l10n.contact_whatsapp_disabled_tooltip,
                  child: AppButton(
                    label: l10n.cta_whatsapp,
                    variant: AppButtonVariant.whatsapp,
                    icon: LucideIcons.message_circle,
                    expanded: true,
                    onPressed: state.whatsappEnabled
                        ? () => ContactActions.whatsApp(
                            context,
                            listing,
                            state.whatsapp!,
                          )
                        : null,
                  ),
                ),
              ),
            if (showPrimaryActions && state.showCall)
              Expanded(
                child: AppButton(
                  label: l10n.cta_call,
                  variant: AppButtonVariant.outlined,
                  icon: Icons.phone_outlined,
                  expanded: true,
                  onPressed: () =>
                      ContactActions.call(context, listing, state.phone!),
                ),
              ),
          ];

          // In-app options demoted to quiet, small text buttons beneath the
          // primary pair: Send inquiry (FR-001c), Request a viewing, and
          // Message. Same handlers/visibility as before — only the visual
          // emphasis changed. A Wrap keeps longer Arabic labels from
          // truncating on narrow widths.
          final quietActions = Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              if (state.showInquiry)
                TextButton.icon(
                  onPressed: () => ContactActions.sendInquiry(context, listing),
                  icon: const Icon(Icons.email_outlined, size: AppSpacing.lg),
                  label: Text(l10n.cta_send_inquiry),
                ),
              TextButton.icon(
                onPressed: () =>
                    ContactActions.requestViewing(context, listing),
                icon: const Icon(
                  Icons.calendar_today_outlined,
                  size: AppSpacing.lg,
                ),
                label: Text(l10n.viewingRequestAction),
              ),
              TextButton.icon(
                onPressed: () => ContactActions.message(context, listing),
                icon: const Icon(Icons.forum_outlined, size: AppSpacing.lg),
                label: Text(l10n.chatContactAction),
              ),
            ],
          );

          // Stack the seller-trust summary (rating + response badge) above
          // the WhatsApp + Call pair and the quiet text-button row. The
          // summary reads the page-provided SellerTrustCubit and collapses
          // when no data.
          final actionStack = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SellerTrustSummary(),
              if (primaryButtons.isNotEmpty)
                Row(children: _interspersed(primaryButtons)),
              if (primaryButtons.isNotEmpty)
                const SizedBox(height: AppSpacing.xs),
              quietActions,
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
                  style: styles.titleMedium.copyWith(color: colors.onSurface),
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
                style: styles.titleMedium.copyWith(color: colors.onSurface),
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

}
