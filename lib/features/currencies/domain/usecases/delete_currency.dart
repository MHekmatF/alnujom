import 'package:injectable/injectable.dart';

import '../repositories/currencies_repository.dart';

@injectable
class DeleteCurrency {
  const DeleteCurrency(this._repository);

  final CurrenciesRepository _repository;

  Future<void> call(String code) => _repository.deleteCurrency(code);
}
