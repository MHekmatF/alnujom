import 'package:alnujom/l10n/app_localizations.dart';
import 'package:alnujom/shared/domain/value_objects/phone_number.dart';

class PhoneValidator {
  static ({String? error, String? normalized}) validateAndNormalize(
    String? value,
    AppLocalizations l10n,
  ) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return (error: l10n.validatorPhoneInvalid, normalized: null);
    }

    final digitCount = RegExp(r'\d').allMatches(trimmed).length;
    if (digitCount < 6) {
      return (error: l10n.validatorPhoneTooShort, normalized: null);
    }

    final normalized = PhoneNumber.tryParse(trimmed)?.e164;
    if (normalized == null) {
      return (error: l10n.validatorPhoneInvalid, normalized: null);
    }

    return (error: null, normalized: normalized);
  }
}
