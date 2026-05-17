import 'package:injectable/injectable.dart';

import '../entities/currency.dart';
import '../repositories/currencies_repository.dart';

@injectable
class CreateCurrency {
  const CreateCurrency(this._repository);

  final CurrenciesRepository _repository;

  Future<Currency> call({
    required String code,
    required String nameAr,
    required String nameEn,
    required String symbol,
    int sortOrder = 100,
    int displayDecimals = 2,
    bool isActive = true,
  }) {
    return _repository.createCurrency(
      code: code,
      nameAr: nameAr,
      nameEn: nameEn,
      symbol: symbol,
      sortOrder: sortOrder,
      displayDecimals: displayDecimals,
      isActive: isActive,
    );
  }
}
