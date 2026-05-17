import 'package:decimal/decimal.dart';
import 'package:injectable/injectable.dart';

import '../entities/update_exchange_rate_result.dart';
import '../repositories/currencies_repository.dart';

@injectable
class SetExchangeRate {
  const SetExchangeRate(this._repository);

  final CurrenciesRepository _repository;

  Future<UpdateExchangeRateResult> call({
    required String baseCurrency,
    required String targetCurrency,
    required Decimal rate,
    required DateTime effectiveAt,
    String? source,
  }) {
    return _repository.setExchangeRate(
      baseCurrency: baseCurrency,
      targetCurrency: targetCurrency,
      rate: rate,
      effectiveAt: effectiveAt,
      source: source,
    );
  }
}
