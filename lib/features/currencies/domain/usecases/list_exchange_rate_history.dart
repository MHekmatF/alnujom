import 'package:injectable/injectable.dart';

import '../entities/exchange_rate.dart';
import '../repositories/currencies_repository.dart';

@injectable
class ListExchangeRateHistory {
  const ListExchangeRateHistory(this._repository);

  final CurrenciesRepository _repository;

  Future<List<ExchangeRate>> call({
    required String baseCurrency,
    String? targetCurrencyFilter,
    int limit = 50,
    DateTime? cursorBefore,
  }) {
    return _repository.listExchangeRateHistory(
      baseCurrency: baseCurrency,
      targetCurrencyFilter: targetCurrencyFilter,
      limit: limit,
      cursorBefore: cursorBefore,
    );
  }
}
