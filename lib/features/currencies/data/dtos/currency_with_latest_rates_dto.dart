import 'package:decimal/decimal.dart';

import '../../domain/entities/currency_with_latest_rates.dart';
import 'currency_dto.dart';

class CurrencyWithLatestRatesDto {
  const CurrencyWithLatestRatesDto({
    required this.currency,
    required this.latestRates,
  });

  final CurrencyDto currency;
  final Map<String, Decimal> latestRates;

  CurrencyWithLatestRates toDomain() {
    return CurrencyWithLatestRates(
      currency: currency.toDomain(),
      latestRates: latestRates,
    );
  }
}
