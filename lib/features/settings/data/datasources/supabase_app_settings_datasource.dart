import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/app_setting_key.dart';
import '../dtos/app_setting_dto.dart';

/// Supabase datasource for `public.app_settings`.
///
/// Mirrors the Phase 9 `SupabaseCurrenciesDatasource` idiom:
/// - reads via `_client.from('app_settings').select()`
/// - writes via `_client.rpc('set_app_setting', params: {...})`
///
/// RLS is enforced transparently by PostgREST:
/// - Non-`settings.manage` callers receive only `is_public = true` rows.
/// - `settings.manage` holders receive all rows.
/// - Writes are routed through the `set_app_setting` SECURITY DEFINER RPC
///   which re-checks `settings.manage` server-side (R-199).
@injectable
class SupabaseAppSettingsDatasource {
  SupabaseAppSettingsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Fetch all app settings rows visible to the current caller (RLS applied).
  Future<List<AppSettingDto>> fetchSettings() async {
    final rows = await _client
        .from('app_settings')
        .select()
        .order('key', ascending: true);
    return rows.map(AppSettingDto.fromJson).toList();
  }

  /// Persist a setting change via the `set_app_setting` SECURITY DEFINER RPC.
  ///
  /// [key] — the [AppSettingKey] to update.
  /// [value] — the new Dart value; encoded as a JSON string before calling the
  ///   RPC so PostgREST receives it as a valid JSONB argument.
  ///
  /// Returns the updated row as an [AppSettingDto].
  ///
  /// Throws [supabase.PostgrestException] with:
  /// - code `'42501'` if the caller lacks `settings.manage`.
  /// - code `'P0002'` if [key] is not in the v1 catalog (should not happen
  ///   when callers use the [AppSettingKey] enum).
  Future<AppSettingDto> updateSetting(AppSettingKey key, Object value) async {
    final result = await _client.rpc(
      'set_app_setting',
      params: {
        'p_key': key.key,
        'p_value': jsonDecode(jsonEncode(value)),
      },
    );
    // The RPC returns the updated row as a single object.
    final row = Map<String, dynamic>.from(result as Map);
    return AppSettingDto.fromJson(row);
  }
}
