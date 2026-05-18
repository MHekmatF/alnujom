import 'package:injectable/injectable.dart';

import '../entities/currency.dart';
import '../repositories/currencies_repository.dart';

@injectable
class LoadCurrencyDetail {
  const LoadCurrencyDetail(this._repository);

  final CurrenciesRepository _repository;

  Future<Currency> call(String code) => _repository.loadCurrency(code);
}
