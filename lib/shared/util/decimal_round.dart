import 'package:decimal/decimal.dart';

/// Returns [value] rounded to [scale] decimal places using banker's rounding
/// (half-to-even). For exact half cases, rounds to the nearest even last digit.
///
/// Used by the display layer (`MoneyFormatter`). The storage layer uses
/// Postgres's half-away-from-zero — this divergence is intentional per
/// research.md R-11.
Decimal roundHalfEven(Decimal value, int scale) {
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

/// Returns [value] rounded to [scale] decimal places using half-away-from-zero
/// rounding. Matches Postgres's built-in `round()` function — use for derived
/// previews so the displayed value matches what the database will store after
/// the `update_exchange_rate` RPC inserts it.
Decimal roundHalfAwayFromZero(Decimal value, int scale) {
  if (scale < 0) throw ArgumentError.value(scale, 'scale', 'must be >= 0');
  final factor = Decimal.fromInt(10).pow(scale).toDecimal();
  final scaled = value * factor;
  final truncated = scaled.truncate();
  final fractional = scaled - truncated;
  final absFrac = fractional.abs();
  final half = Decimal.parse('0.5');
  final rounded = absFrac < half
      ? truncated
      : (value.sign >= 0 ? truncated + Decimal.one : truncated - Decimal.one);
  return (rounded / factor).toDecimal(scaleOnInfinitePrecision: scale);
}
