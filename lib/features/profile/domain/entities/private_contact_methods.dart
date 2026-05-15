import 'package:equatable/equatable.dart';

/// Allowed contact channels for `private_contact_methods` (FR-005, R-13).
/// Mirrors the SQL allowlist enforced by `app_vault_set_private_contact_methods_for_self`.
enum ContactChannel {
  whatsapp('whatsapp'),
  telegram('telegram'),
  signal('signal'),
  privateEmail('private_email'),
  secondaryPhone('secondary_phone');

  const ContactChannel(this.jsonKey);

  /// Wire-level JSON key. MUST match the SQL allowlist.
  final String jsonKey;

  static ContactChannel? tryFromJsonKey(String key) {
    for (final c in ContactChannel.values) {
      if (c.jsonKey == key) return c;
    }
    return null;
  }
}

/// Domain value object for the user's private contact methods.
/// Stored encrypted in `vault.secrets` keyed `pii.<user_id>.private_contact_methods`
/// (Phase 5 R-13).
class PrivateContactMethods extends Equatable {
  const PrivateContactMethods(this.channels);

  /// Immutable map. Keys are typed; values are user-supplied handles/numbers/addresses.
  final Map<ContactChannel, String> channels;

  /// Parses from the JSON shape stored in Vault. Unknown keys are rejected.
  factory PrivateContactMethods.fromJson(Map<String, dynamic> json) {
    final result = <ContactChannel, String>{};
    json.forEach((key, value) {
      final channel = ContactChannel.tryFromJsonKey(key);
      if (channel == null) {
        throw FormatException('unknown_contact_channel:$key');
      }
      if (value is! String) {
        throw FormatException('non_string_contact_value:$key');
      }
      result[channel] = value;
    });
    return PrivateContactMethods(Map.unmodifiable(result));
  }

  Map<String, dynamic> toJson() => {
    for (final entry in channels.entries) entry.key.jsonKey: entry.value,
  };

  @override
  List<Object?> get props => [channels];
}
