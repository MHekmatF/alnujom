import 'package:decimal/decimal.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/currency.dart';
import '../../domain/entities/exchange_rate.dart';
import '../../domain/entities/update_exchange_rate_result.dart';
import '../../domain/repositories/currencies_repository.dart';
import '../datasources/supabase_currencies_datasource.dart';
import '../dtos/currency_mutation_request_dto.dart';
import '../dtos/update_exchange_rate_request_dto.dart';

@LazySingleton(as: CurrenciesRepository)
class CurrenciesRepositoryImpl implements CurrenciesRepository {
  CurrenciesRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'CurrenciesRepositoryImpl';

  final SupabaseCurrenciesDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<List<Currency>> listCurrencies({bool activeOnly = false}) async {
    try {
      final dtos = await _datasource.listCurrencies(activeOnly: activeOnly);
      return dtos.map((dto) => dto.toDomain()).toList();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<Currency> loadCurrency(String code) async {
    try {
      return (await _datasource.loadCurrency(code)).toDomain();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<Currency> createCurrency({
    required String code,
    required String nameAr,
    required String nameEn,
    required String symbol,
    int sortOrder = 100,
    int displayDecimals = 2,
    bool isActive = true,
  }) async {
    try {
      return (await _datasource.createCurrency(
        CurrencyMutationRequestDto(
          code: code,
          nameAr: nameAr,
          nameEn: nameEn,
          symbol: symbol,
          sortOrder: sortOrder,
          displayDecimals: displayDecimals,
          isActive: isActive,
        ),
      )).toDomain();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<Currency> updateCurrency(Currency updated) async {
    try {
      return (await _datasource.updateCurrency(
        CurrencyMutationRequestDto(
          code: updated.code,
          nameAr: updated.nameAr,
          nameEn: updated.nameEn,
          symbol: updated.symbol,
          sortOrder: updated.sortOrder,
          displayDecimals: updated.displayDecimals,
          isActive: updated.isActive,
        ),
      )).toDomain();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<void> deleteCurrency(String code) async {
    try {
      await _datasource.deleteCurrency(code);
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<List<ExchangeRate>> listExchangeRateHistory({
    required String baseCurrency,
    String? targetCurrencyFilter,
    int limit = 50,
    DateTime? cursorBefore,
  }) async {
    try {
      final dtos = await _datasource.listExchangeRateHistory(
        baseCurrency: baseCurrency,
        targetCurrencyFilter: targetCurrencyFilter,
        limit: limit,
        cursorBefore: cursorBefore,
      );
      return dtos.map((dto) => dto.toDomain()).toList();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<Map<String, Decimal>> loadLatestRatesForBase(
    String baseCurrency,
  ) async {
    try {
      return await _datasource.loadLatestRatesForBase(baseCurrency);
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<UpdateExchangeRateResult> setExchangeRate({
    required String baseCurrency,
    required String targetCurrency,
    required Decimal rate,
    required DateTime effectiveAt,
    String? source,
  }) async {
    try {
      return (await _datasource.setExchangeRate(
        UpdateExchangeRateRequestDto(
          baseCurrency: baseCurrency,
          targetCurrency: targetCurrency,
          rate: rate,
          effectiveAt: effectiveAt,
          sourceText: source,
        ),
      )).toDomain();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<String?> readUserDisplayCurrency() async {
    try {
      return await _datasource.readUserDisplayCurrency();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<void> writeUserDisplayCurrency(String code) async {
    try {
      await _datasource.writeUserDisplayCurrency(code);
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<int> countDependentExchangeRates(String code) async {
    try {
      return await _datasource.countDependentExchangeRates(code);
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  CurrenciesFailure _mapPostgrest(PostgrestException e, StackTrace st) {
    _logger.warning(
      'Currencies data error.',
      error: e,
      stackTrace: st,
      tag: _tag,
    );
    final code = e.code ?? '';
    final message = e.message;
    final lower = message.toLowerCase();
    if (lower.contains('system') || lower.contains('immutable')) {
      return CurrenciesSystemRowImmutable(message);
    }
    return switch (code) {
      '42501' => CurrenciesPermissionDenied(message),
      '22023' => CurrenciesValidationFailed(
        _validationReason(message),
        message,
      ),
      '23503' => CurrenciesHasReferences(message),
      '23505' => CurrenciesDuplicateCode(message),
      _ => CurrenciesUnknown(message),
    };
  }

  CurrenciesFailure _mapUnknown(Object e, StackTrace st) {
    _logger.warning(
      'Currencies unexpected error.',
      error: e,
      stackTrace: st,
      tag: _tag,
    );
    return CurrenciesUnknown(e.toString());
  }

  String _validationReason(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('rate must be positive')) return 'rate_must_be_positive';
    if (lower.contains('base_currency and target_currency must differ')) {
      return 'base_equals_target';
    }
    if (lower.contains('display_decimals')) return 'display_decimals_range';
    return 'validation_failed';
  }
}

sealed class CurrenciesFailure implements Exception {
  final String technicalMessage;

  const CurrenciesFailure(this.technicalMessage);
}

class CurrenciesPermissionDenied extends CurrenciesFailure {
  const CurrenciesPermissionDenied(super.technicalMessage);
}

class CurrenciesValidationFailed extends CurrenciesFailure {
  final String reason;

  const CurrenciesValidationFailed(this.reason, super.technicalMessage);
}

class CurrenciesSystemRowImmutable extends CurrenciesFailure {
  const CurrenciesSystemRowImmutable(super.technicalMessage);
}

class CurrenciesHasReferences extends CurrenciesFailure {
  const CurrenciesHasReferences(super.technicalMessage);
}

class CurrenciesDuplicateCode extends CurrenciesFailure {
  const CurrenciesDuplicateCode(super.technicalMessage);
}

class CurrenciesUnknown extends CurrenciesFailure {
  const CurrenciesUnknown(super.technicalMessage);
}
