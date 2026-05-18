import 'package:decimal/decimal.dart';
import 'package:injectable/injectable.dart';

import '../repositories/currencies_repository.dart';

@lazySingleton
class LoadLatestRatesForBase {
  const LoadLatestRatesForBase(this._repository);

  final CurrenciesRepository _repository;

  Future<Map<String, Decimal>> call(String baseCurrency) =>
      _repository.loadLatestRatesForBase(baseCurrency);
}
