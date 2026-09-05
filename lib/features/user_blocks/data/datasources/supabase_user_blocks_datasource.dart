// Plan A29 — SOLE importer of supabase_flutter under lib/features/user_blocks/
// (Constitution IX). Four RPCs, nothing else: the `user_blocks` table has no
// client grants, so there is no table access to be had here.
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

@injectable
class SupabaseUserBlocksDatasource {
  SupabaseUserBlocksDatasource(this._client);

  final supabase.SupabaseClient _client;

  Future<void> block(String userId) async {
    await _client.rpc<dynamic>('block_user', params: {'p_user_id': userId});
  }

  Future<void> unblock(String userId) async {
    await _client.rpc<dynamic>('unblock_user', params: {'p_user_id': userId});
  }

  Future<bool> isBlocked(String userId) async {
    final result = await _client.rpc<dynamic>(
      'is_user_blocked_by_me',
      params: {'p_user_id': userId},
    );
    return result == true;
  }

  /// Rows: `{user_id, full_name, blocked_at}`, newest first.
  Future<List<Map<String, dynamic>>> listBlocked() async {
    final rows = await _client.rpc<dynamic>('list_my_blocks');
    return (rows as List<dynamic>)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }
}
