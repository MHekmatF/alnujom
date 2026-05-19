import 'package:alnujom/features/currencies/domain/entities/currency.dart';
import 'package:alnujom/l10n/app_localizations.dart';
import 'package:decimal/decimal.dart';

class PriceValidator {
  static String? validate(
    Decimal? value,
    Currency currency,
    AppLocalizations l10n,
  ) {
    if (value == null || value <= Decimal.zero) {
      return l10n.validatorPricePositive;
    }

    final parts = value.toString().split('.');
    final integerDigits = parts.first.replaceFirst(RegExp(r'^-'), '').length;
    final fractionalDigits = parts.length == 2 ? parts.last.length : 0;

    if (integerDigits > 12 || fractionalDigits > 2) {
      return l10n.validatorPriceTooPrecise;
    }

    // Currency display precision overage is accepted here; save-time logic may round.
    return null;
  }
}
