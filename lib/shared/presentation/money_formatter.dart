import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart' as intl;

import '../domain/value_objects/money.dart';
import '../util/decimal_round.dart';
import '../../features/currencies/domain/entities/currency.dart';

/// Per Q1 / SC-023: no rate parameter; no conversion; pure display utility.
/// Per R-17: no global state; per-call NumberFormat instantiation is fine at MVP scale.
///
/// DC "Blue Crown" design: **Western digits** with comma grouping in both
/// locales ("$210,000"), matching the approved `AlNujom.dc.html` and how real
/// Arabic marketplace apps render prices. A single-ASCII currency symbol ($)
/// prefixes the amount in both `ar` and `en`; word symbols (ل.س / SYP) trail.
class MoneyFormatter {
  static String format(
    Money money, {
    required Locale locale,
    required Currency currency,
  }) {
    final rounded = roundHalfEven(money.amount, currency.displayDecimals);
    final symbol = _resolveSymbol(currency, locale);

    // Whole amounts drop fraction digits; fractional amounts keep them.
    final isWhole = rounded == Decimal.fromBigInt(rounded.toBigInt());
    final fractionDigits = isWhole ? 0 : currency.displayDecimals;
    final numFormat = intl.NumberFormat.decimalPattern('en')
      ..minimumFractionDigits = fractionDigits
      ..maximumFractionDigits = fractionDigits;

    final isNegative = rounded < Decimal.zero;
    final absStr = numFormat.format(rounded.abs().toDouble());
    final sign = isNegative ? '-' : '';

    // Single ASCII printable symbol (e.g. '$') → prefix; word symbols → suffix.
    final isAsciiSymbol =
        symbol.length == 1 &&
        symbol.codeUnitAt(0) >= 0x21 &&
        symbol.codeUnitAt(0) <= 0x7E;
    return isAsciiSymbol ? '$sign$symbol$absStr' : '$sign$absStr $symbol';
  }

  /// R-12: SYP symbol override per locale.
  static String _resolveSymbol(Currency currency, Locale locale) {
    if (locale.languageCode == 'ar' && currency.code == 'SYP') return 'ل.س';
    if (locale.languageCode == 'en' && currency.code == 'SYP') return 'SYP';
    return currency.symbol;
  }

  /// Symbols for the codes the read-side surfaces carry when no full [Currency]
  /// catalog is on hand (search results, favorites, recently-viewed, the detail
  /// price shim). Keeps every card on the DC "$210,000" format instead of the
  /// "210,000 USD" the raw code produced.
  static const Map<String, String> _codeSymbols = {
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'TRY': '₺',
  };

  /// Resolves a display symbol from a bare currency [code]. `SYP` follows the
  /// locale (ل.س / SYP); unknown codes fall back to the code itself.
  static String symbolForCode(String code, {Locale? locale}) {
    if (code == 'SYP') {
      return locale?.languageCode == 'en' ? 'SYP' : 'ل.س';
    }
    return _codeSymbols[code] ?? code;
  }

  /// Formats a bare (amount, currencyCode) pair the DC way — Western digits with
  /// comma grouping, an ASCII symbol ($) prefixed and word symbols (ل.س) trailed
  /// — for the surfaces that don't have a [Currency] object. Mirrors [format].
  static String formatAmount(
    num amount,
    String currencyCode, {
    required Locale locale,
  }) {
    final symbol = symbolForCode(currencyCode, locale: locale);
    final isWhole = amount == amount.roundToDouble();
    final numFormat = intl.NumberFormat.decimalPattern('en')
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = isWhole ? 0 : 2;
    final isNegative = amount < 0;
    final absStr = numFormat.format(amount.abs());
    final sign = isNegative ? '-' : '';
    final isAsciiSymbol =
        symbol.length == 1 &&
        symbol.codeUnitAt(0) >= 0x21 &&
        symbol.codeUnitAt(0) <= 0x7E;
    return isAsciiSymbol ? '$sign$symbol$absStr' : '$sign$absStr $symbol';
  }
}
