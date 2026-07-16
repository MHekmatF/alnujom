import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../features/chat/domain/usecases/get_or_create_conversation.dart';
import '../../../../features/chat/presentation/bloc/chat_thread_cubit.dart';
import '../../../../features/chat/presentation/pages/chat_thread_page.dart';
import '../../../../features/inquiries/domain/entities/lead_event_type.dart';
import '../../../../features/inquiries/domain/usecases/record_lead_event.dart';
import '../../../../features/inquiries/presentation/sheets/inquiry_form_sheet.dart';
import '../../../../features/listing_form/domain/entities/listing.dart';
import '../../../../features/viewings/presentation/sheets/request_viewing_sheet.dart';
import '../../../../l10n/app_localizations.dart';

/// Shared contact/chat launch logic for the listing-detail contact surfaces —
/// the inline [ContactBlock] and the DC sticky bottom bar both call these, so
/// the `wa.me` composition, lead-event analytics, and conversation creation live
/// in one place instead of being duplicated across the two.
abstract final class ContactActions {
  /// Canonical https base for the pre-filled WhatsApp listing link — mirrors
  /// `PerListingActionBlock._shareLinkBase` so both deep links stay identical.
  static const String _waLinkBase = 'https://alnujom.app';

  /// Opens the dialer (`tel:`) for the listing's contact number and records the
  /// phone-revealed lead event.
  static Future<void> call(
    BuildContext context,
    Listing listing,
    String phone,
  ) async {
    await getIt<RecordLeadEvent>()(
      listingId: listing.id,
      eventType: LeadEventType.phoneRevealed,
    );
    final launched = await launchUrl(Uri.parse('tel:$phone'));
    if (!launched && context.mounted) {
      AppToast.error(
        context,
        AppLocalizations.of(context)!.contact_dialer_unavailable,
      );
    }
  }

  /// Opens `wa.me` with the Phase-28 localized pre-filled message (listing title
  /// + canonical link) and records the whatsapp-clicked lead event.
  static Future<void> whatsApp(
    BuildContext context,
    Listing listing,
    String whatsapp,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final link = '$_waLinkBase${AppRoutes.listingDetailsFor(listing.id)}';
    final e164NoPlus = whatsapp.replaceAll('+', '');
    final uri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: e164NoPlus,
      queryParameters: {
        'text': l10n.contactWhatsappPrefill(listing.title, link),
      },
    );
    await getIt<RecordLeadEvent>()(
      listingId: listing.id,
      eventType: LeadEventType.whatsappClicked,
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppToast.error(context, l10n.contact_whatsapp_app_unavailable);
    }
  }

  /// Opens the inquiry form sheet (FR-001c).
  static void sendInquiry(BuildContext context, Listing listing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => InquiryFormSheet(listingId: listing.id),
    );
  }

  /// Request-a-viewing entry. Anonymous → sign-in toast; signed-in → the
  /// date/time request sheet, with the standard confirmation toast on success.
  static Future<void> requestViewing(
    BuildContext context,
    Listing listing,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (getIt<AuthBloc>().state is! Authenticated) {
      AppToast.warning(context, l10n.chatSignInPrompt);
      return;
    }
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RequestViewingSheet(listingId: listing.id),
    );
    if (submitted == true && context.mounted) {
      AppToast.success(context, l10n.viewingRequestSuccess);
    }
  }

  /// In-app chat entry. Anonymous → sign-in toast; signed-in → open (or create)
  /// the conversation for this listing, then push the thread page.
  static Future<void> message(BuildContext context, Listing listing) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    if (getIt<AuthBloc>().state is! Authenticated) {
      AppToast.warning(context, l10n.chatSignInPrompt);
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
        AppToast.error(context, l10n.chatOpenError);
    }
  }
}
