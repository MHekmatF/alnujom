// Plan A38 — SOLE importer of supabase_flutter under lib/features/data_export/
// per Constitution IX. One call: the export_my_data Edge Function.

import 'dart:convert';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

@injectable
class SupabaseDataExportDatasource {
  const SupabaseDataExportDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Invokes `export_my_data`. The client attaches the session's own access
  /// token, which is the only credential the function accepts. The function
  /// answers JSON; it is re-encoded here with an indent so the file a person
  /// receives is readable in any text viewer.
  ///
  /// Throws [supabase.FunctionException] on a non-2xx answer (401 when the
  /// token is missing or stale) and [StateError] on an unexpected body.
  Future<Uint8List> download() async {
    final response = await _client.functions.invoke('export_my_data');
    final data = response.data;
    if (data is! Map) {
      throw StateError('export_my_data answered ${response.status}');
    }
    final text = const JsonEncoder.withIndent('  ').convert(data);
    return Uint8List.fromList(utf8.encode(text));
  }
}
