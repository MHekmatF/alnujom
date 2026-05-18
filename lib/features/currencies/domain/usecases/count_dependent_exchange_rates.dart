import 'package:injectable/injectable.dart';

import '../repositories/currencies_repository.dart';

@injectable
class CountDependentExchangeRates {
  const CountDependentExchangeRates(this._repository);

  final CurrenciesRepository _repository;

  Future<int> call(String code) =>
      _repository.countDependentExchangeRates(code);
}
