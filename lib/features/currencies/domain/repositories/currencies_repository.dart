import 'package:decimal/decimal.dart';

import '../entities/currency.dart';
import '../entities/exchange_rate.dart';
import '../entities/update_exchange_rate_result.dart';

/// Phase 9 permission gate: `PermissionKeys.currenciesManage` = `currencies.manage`.
abstract class CurrenciesRepository {
  Future<List<Currency>> listCurrencies({bool activeOnly = false});

  Future<Currency> loadCurrency(String code);

  Future<Currency> createCurrency({
    required String code,
    required String nameAr,
    required String nameEn,
    required String symbol,
    int sortOrder = 100,
    int displayDecimals = 2,
    bool isActive = true,
  });

  Future<Currency> updateCurrency(Currency updated);

  Future<void> deleteCurrency(String code);

  Future<List<ExchangeRate>> listExchangeRateHistory({
    required String baseCurrency,
    String? targetCurrencyFilter,
    int limit = 50,
    DateTime? cursorBefore,
  });

  Future<Map<String, Decimal>> loadLatestRatesForBase(String baseCurrency);

  Future<UpdateExchangeRateResult> setExchangeRate({
    required String baseCurrency,
    required String targetCurrency,
    required Decimal rate,
    required DateTime effectiveAt,
    String? source,
  });

  Future<String?> readUserDisplayCurrency();

  Future<void> writeUserDisplayCurrency(String code);

  Future<int> countDependentExchangeRates(String code);
}
