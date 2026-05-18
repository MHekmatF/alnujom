import 'package:decimal/decimal.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/currency_dto.dart';
import '../dtos/currency_mutation_request_dto.dart';
import '../dtos/exchange_rate_dto.dart';
import '../dtos/update_exchange_rate_request_dto.dart';
import '../dtos/update_exchange_rate_response_dto.dart';

@injectable
class SupabaseCurrenciesDatasource {
  SupabaseCurrenciesDatasource(this._client);

  final supabase.SupabaseClient _client;

  Future<List<CurrencyDto>> listCurrencies({bool activeOnly = false}) async {
    var query = _client.from('currencies').select();
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query
        .order('sort_order', ascending: true)
        .order('code', ascending: true);
    return rows.map(CurrencyDto.fromJson).toList();
  }

  Future<CurrencyDto> loadCurrency(String code) async {
    final row = await _client
        .from('currencies')
        .select()
        .eq('code', code)
        .single();
    return CurrencyDto.fromJson(row);
  }

  Future<CurrencyDto> createCurrency(CurrencyMutationRequestDto request) async {
    final row = await _client
        .from('currencies')
        .insert(request.toRow())
        .select()
        .single();
    return CurrencyDto.fromJson(row);
  }

  Future<CurrencyDto> updateCurrency(CurrencyMutationRequestDto request) async {
    final row = await _client
        .from('currencies')
        .update(request.toRow())
        .eq('code', request.code)
        .select()
        .single();
    return CurrencyDto.fromJson(row);
  }

  Future<void> deleteCurrency(String code) async {
    await _client.from('currencies').delete().eq('code', code);
  }

  Future<List<ExchangeRateDto>> listExchangeRateHistory({
    required String baseCurrency,
    String? targetCurrencyFilter,
    int limit = 50,
    DateTime? cursorBefore,
  }) async {
    var query = _client
        .from('exchange_rates')
        .select()
        .eq('base_currency', baseCurrency);
    if (targetCurrencyFilter != null) {
      query = query.eq('target_currency', targetCurrencyFilter);
    }
    if (cursorBefore != null) {
      query = query.lt('created_at', cursorBefore.toUtc().toIso8601String());
    }
    final rows = await query
        .order('effective_at', ascending: false)
        .limit(limit);
    final profileNames = await _loadProfileNames(rows);
    return rows.map((row) {
      final mutable = Map<String, dynamic>.from(row);
      final setBy = mutable['set_by'] as String?;
      if (setBy != null) {
        mutable['profiles'] = {'display_name': profileNames[setBy]};
      }
      return ExchangeRateDto.fromJson(mutable);
    }).toList();
  }

  Future<Map<String, Decimal>> loadLatestRatesForBase(
    String baseCurrency,
  ) async {
    final rows = await _client.rpc(
      'latest_rates_for_base',
      params: {'p_base_currency': baseCurrency},
    );
    final list = rows as List<dynamic>;
    return {
      for (final r in list)
        (r as Map<String, dynamic>)['target_currency'] as String: Decimal.parse(
          r['rate'].toString(),
        ),
    };
  }

  Future<UpdateExchangeRateResponseDto> setExchangeRate(
    UpdateExchangeRateRequestDto request,
  ) async {
    final result = await _client.rpc(
      'update_exchange_rate',
      params: request.toRpcParams(),
    );
    return UpdateExchangeRateResponseDto.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<String?> readUserDisplayCurrency() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('user_preferences')
        .select('display_currency')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['display_currency'] as String?;
  }

  Future<void> writeUserDisplayCurrency(String code) async {
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('user_preferences')
        .update({'display_currency': code})
        .eq('user_id', userId);
  }

  Future<int> countDependentExchangeRates(String code) async {
    final rows = await _client
        .from('exchange_rates')
        .select('id')
        .or('base_currency.eq.$code,target_currency.eq.$code');
    return rows.length;
  }

  Future<Map<String, String>> _loadProfileNames(
    List<Map<String, dynamic>> rows,
  ) async {
    final userIds = rows
        .map((row) => row['set_by'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (userIds.isEmpty) return const {};
    final profiles = await _client
        .from('profiles')
        .select('user_id, full_name, username')
        .inFilter('user_id', userIds);
    final result = <String, String>{};
    for (final row in profiles) {
      final fullName = (row['full_name'] as String?)?.trim();
      final username = (row['username'] as String?)?.trim();
      final name = (fullName != null && fullName.isNotEmpty)
          ? fullName
          : (username != null && username.isNotEmpty ? username : null);
      if (name != null) {
        result[row['user_id'] as String] = name;
      }
    }
    return result;
  }
}
