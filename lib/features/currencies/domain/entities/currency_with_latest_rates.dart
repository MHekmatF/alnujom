import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import 'currency.dart';

class CurrencyWithLatestRates extends Equatable {
  final Currency currency;
  final Map<String, Decimal> latestRates;

  const CurrencyWithLatestRates({
    required this.currency,
    required this.latestRates,
  });

  @override
  List<Object?> get props => [currency, latestRates];
}
