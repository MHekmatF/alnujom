import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart' as intl;

/// Formats an exchange-rate value for display. Unlike `MoneyFormatter` — which
/// rounds to `currency.displayDecimals` and is appropriate for money amounts —
/// this formatter preserves the storage layer's NUMERIC(18,6) precision.
///
/// Use this for widgets rendering a rate (e.g. "1 SYP = 0.000063 USD"), NOT
/// for widgets rendering an amount of money.
///
/// DC "Blue Crown" design: Western digits in both locales (see MoneyFormatter).
class RateFormatter {
  static const int _maxFractionDigits = 6;

  static String format(Decimal rate, Locale locale) {
    final fmt = intl.NumberFormat.decimalPattern('en')
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = _maxFractionDigits;
    return fmt.format(rate.toDouble());
  }
}
