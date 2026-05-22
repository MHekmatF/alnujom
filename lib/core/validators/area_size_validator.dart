import 'package:alnujom/l10n/app_localizations.dart';

class AreaSizeValidator {
  static String? validate(num? value, AppLocalizations l10n) {
    if (value == null || value <= 0) {
      return l10n.validatorAreaSizePositive;
    }
    if (value > 999999) {
      return l10n.validatorAreaSizeTooLarge;
    }
    return null;
  }
}
