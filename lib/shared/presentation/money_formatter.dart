import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart' as intl;

import '../domain/value_objects/money.dart';
import '../../features/currencies/domain/entities/currency.dart';

/// Per Q1 / SC-023: no rate parameter; no conversion; pure display utility.
/// Per R-17: no global state; per-call NumberFormat instantiation is fine at MVP scale.
class MoneyFormatter {
  static String format(
    Money money, {
    required Locale locale,
    required Currency currency,
  }) {
    final rounded = _roundHalfEven(money.amount, currency.displayDecimals);
    final symbol = _resolveSymbol(currency, locale);
    final localeTag = locale.toLanguageTag();

    final numFormat = intl.NumberFormat.decimalPattern(localeTag)
      ..minimumFractionDigits = currency.displayDecimals
      ..maximumFractionDigits = currency.displayDecimals;

    if (locale.languageCode == 'ar') {
      // Arabic: amount then symbol, RTL bidi resolver handles visual order.
      // Sign is included by NumberFormat; negative produces e.g. '-٥٠'.
      final numStr = numFormat.format(rounded.toDouble());
      return '$numStr $symbol';
    } else {
      // en (and fallback): handle sign separately for correct prefix placement.
      final isNegative = rounded < Decimal.zero;
      final absRounded = rounded.abs();
      final absStr = numFormat.format(absRounded.toDouble());

      // Single ASCII printable character (e.g. '$') → prefix position.
      if (symbol.length == 1 && symbol.codeUnitAt(0) >= 0x21 && symbol.codeUnitAt(0) <= 0x7E) {
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

  /// Banker's rounding (half-to-even) enforced at the display layer (R-11).
  /// Storage layer (Postgres round()) is half-away-from-zero; this divergence
  /// is intentional and documented in research.md R-11.
  static Decimal _roundHalfEven(Decimal value, int scale) {
    if (scale < 0) throw ArgumentError.value(scale, 'scale', 'must be >= 0');
    final factor = Decimal.fromInt(10).pow(scale).toDecimal();
    final scaled = value * factor;
    final truncated = scaled.truncate();
    final fractional = scaled - truncated;
    final absFrac = fractional.abs();
    final half = Decimal.parse('0.5');
    Decimal rounded;
    if (absFrac < half) {
      rounded = truncated;
    } else if (absFrac > half) {
      rounded = value.sign >= 0
          ? truncated + Decimal.one
          : truncated - Decimal.one;
    } else {
      // Exactly 0.5 fractional → round to even
      final isEven = (truncated.toBigInt() % BigInt.two) == BigInt.zero;
      if (isEven) {
        rounded = truncated;
      } else {
        rounded = value.sign >= 0
            ? truncated + Decimal.one
            : truncated - Decimal.one;
      }
    }
    return (rounded / factor).toDecimal(scaleOnInfinitePrecision: scale);
  }
}
