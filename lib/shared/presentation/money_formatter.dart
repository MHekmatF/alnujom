import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart' as intl;

import '../domain/value_objects/money.dart';
import '../util/arabic_digits.dart';
import '../util/decimal_round.dart';
import '../../features/currencies/domain/entities/currency.dart';

/// Per Q1 / SC-023: no rate parameter; no conversion; pure display utility.
/// Per R-17: no global state; per-call NumberFormat instantiation is fine at MVP scale.
class MoneyFormatter {
  static String format(
    Money money, {
    required Locale locale,
    required Currency currency,
  }) {
    final rounded = roundHalfEven(money.amount, currency.displayDecimals);
    final symbol = _resolveSymbol(currency, locale);
    final localeTag = locale.toLanguageTag();

    // 035 craft wave: whole amounts drop their fraction digits entirely —
    // `١٢٠٬٠٠٠٫٠٠ $` on a property card reads as filler, not precision.
    // Fractional amounts keep the currency's configured decimals.
    final isWhole = rounded == Decimal.fromBigInt(rounded.toBigInt());
    final fractionDigits = isWhole ? 0 : currency.displayDecimals;
    final numFormat = intl.NumberFormat.decimalPattern(localeTag)
      ..minimumFractionDigits = fractionDigits
      ..maximumFractionDigits = fractionDigits;

    if (locale.languageCode == 'ar') {
      // Arabic: amount then symbol, RTL bidi resolver handles visual order.
      // intl's bundled 'ar' data uses Western digits, so post-process to
      // Arabic-Indic per R-12 / FR-022.
      final numStr = toArabicIndicNumerals(
        numFormat.format(rounded.toDouble()),
      );
      return '$numStr $symbol';
    } else {
      // en (and fallback): handle sign separately for correct prefix placement.
      final isNegative = rounded < Decimal.zero;
      final absRounded = rounded.abs();
      final absStr = numFormat.format(absRounded.toDouble());

      // Single ASCII printable character (e.g. '$') → prefix position.
      if (symbol.length == 1 &&
          symbol.codeUnitAt(0) >= 0x21 &&
          symbol.codeUnitAt(0) <= 0x7E) {
        return isNegative ? '-$symbol$absStr' : '$symbol$absStr';
      } else {
        return isNegative ? '-$absStr $symbol' : '$absStr $symbol';
      }
    }
  }

  /// R-12: SYP symbol override per locale.
  static String _resolveSymbol(Currency currency, Locale locale) {
    if (locale.languageCode == 'ar' && currency.code == 'SYP') return 'ل.س';
    if (locale.languageCode == 'en' && currency.code == 'SYP') return 'SYP';
    return currency.symbol;
  }
}
