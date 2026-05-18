import 'package:injectable/injectable.dart';

import '../entities/currency.dart';
import '../repositories/currencies_repository.dart';

@injectable
class ListCurrencies {
  const ListCurrencies(this._repository);

  final CurrenciesRepository _repository;

  Future<List<Currency>> call({bool activeOnly = false}) {
    return _repository.listCurrencies(activeOnly: activeOnly);
  }
}
