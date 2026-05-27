// lib/features/inquiries/presentation/bloc/contact_cta_cubit.dart
//
// Phase 16 Sub-Phase F (T063) — Cubit computing the CTA visibility state for
// the ContactBlock on a listing details page.
//
// Factory-scoped: one instance per listing details page. @factoryParam injects
// the Listing. The auth state is read once at construction time via
// getIt<AuthBloc>() — a one-shot read is safe because this cubit is disposed
// when the user navigates away from the listing details page.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../listing_form/domain/entities/listing.dart';

part 'contact_cta_state.dart';

@injectable
class ContactCtaCubit extends Cubit<ContactCtaState> {
  ContactCtaCubit(
    @factoryParam Listing listing,
  ) : super(_compute(listing, getIt<AuthBloc>().state));

  /// Derives visibility flags from the [Listing] + the current [AuthState].
  ///
  /// FR-001d self-contact guard: when the authenticated user IS the publisher,
  /// all CTA flags are false so the ContactBlock renders a placeholder instead.
  static ContactCtaState _compute(Listing listing, AuthState authState) {
    // FR-001d: self-contact — hide all CTAs for the listing's own publisher.
    if (authState is Authenticated &&
        authState.profile.userId == listing.publisherUserId) {
      return const ContactCtaState(isSelfContact: true);
    }

    // FR-001a: Call CTA visible only when a non-empty phone number is present.
    final showCall =
        listing.phone != null && listing.phone!.isNotEmpty;

    // FR-001b (Q1=B-refined): WhatsApp button always renders but is disabled
    // when no whatsapp number is stored.
    const showWhatsApp = true;
    final whatsappEnabled =
        listing.whatsapp != null && listing.whatsapp!.isNotEmpty;

    // FR-001c: Send Inquiry is always available for non-self-contact.
    const showInquiry = true;

    return ContactCtaState(
      phone: listing.phone,
      whatsapp: listing.whatsapp,
      showCall: showCall,
      showWhatsApp: showWhatsApp,
      whatsappEnabled: whatsappEnabled,
      showInquiry: showInquiry,
      isSelfContact: false,
    );
  }
}
