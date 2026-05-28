// lib/features/inquiries/presentation/bloc/contact_cta_state.dart
part of 'contact_cta_cubit.dart';

/// CTA visibility state for the ContactBlock widget.
///
/// When [isSelfContact] is true all other flags are false and the ContactBlock
/// should render a "This is your listing" placeholder.
final class ContactCtaState extends Equatable {
  const ContactCtaState({
    this.phone,
    this.whatsapp,
    this.showCall = false,
    this.showWhatsApp = false,
    this.whatsappEnabled = false,
    this.showInquiry = false,
    this.isSelfContact = false,
  });

  final String? phone;
  final String? whatsapp;

  /// Whether to show the Call button (FR-001a: requires a non-empty phone).
  final bool showCall;

  /// Whether to show the WhatsApp button — always true per Q1=B-refined.
  final bool showWhatsApp;

  /// Whether the WhatsApp button is tappable (false when whatsapp is empty).
  final bool whatsappEnabled;

  /// Whether to show the Send Inquiry button (always true unless self-contact).
  final bool showInquiry;

  /// True when the signed-in user is the listing's publisher (FR-001d).
  final bool isSelfContact;

  @override
  List<Object?> get props => [
    phone,
    whatsapp,
    showCall,
    showWhatsApp,
    whatsappEnabled,
    showInquiry,
    isSelfContact,
  ];
}
