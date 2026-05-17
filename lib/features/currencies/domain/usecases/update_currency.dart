import 'package:injectable/injectable.dart';

import '../entities/currency.dart';
import '../repositories/currencies_repository.dart';

@injectable
class UpdateCurrency {
  const UpdateCurrency(this._repository);

  final CurrenciesRepository _repository;

  Future<Currency> call(Currency updated) =>
      _repository.updateCurrency(updated);
}
