/// Multi-channel support contact info surfaced in the app and on the
/// maintenance screen (data-model §1.3, key: `support_contact`).
///
/// Any or all channels may be null (not yet configured).
class SupportContact {
  const SupportContact({this.phone, this.whatsapp, this.email});

  /// Phone number string, or null if not configured.
  final String? phone;

  /// WhatsApp number/link, or null if not configured.
  final String? whatsapp;

  /// Email address, or null if not configured.
  final String? email;

  /// Returns `true` if at least one channel is set.
  ///
  /// FC uses this to decide whether to render the support section at all
  /// (never show an empty contact card).
  bool get hasAny =>
      (phone != null && phone!.isNotEmpty) ||
      (whatsapp != null && whatsapp!.isNotEmpty) ||
      (email != null && email!.isNotEmpty);

  @override
  String toString() =>
      'SupportContact(phone: $phone, whatsapp: $whatsapp, email: $email)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupportContact &&
          runtimeType == other.runtimeType &&
          phone == other.phone &&
          whatsapp == other.whatsapp &&
          email == other.email;

  @override
  int get hashCode => phone.hashCode ^ whatsapp.hashCode ^ email.hashCode;
}
