// Plan A34 — SOLE importer of supabase_flutter under lib/features/feedback/
// per Constitution IX. One RPC: submit_feedback.

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

@injectable
class SupabaseFeedbackDatasource {
  const SupabaseFeedbackDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Returns the new feedback row id.
  ///
  /// Throws [supabase.PostgrestException] on 42501 (signed out), 22023 (bad
  /// category) and 23514 (length, or the ten-messages-an-hour throttle).
  Future<String> submit({
    required String category,
    required String message,
    String? appBuild,
    String? platform,
  }) async {
    final result = await _client.rpc(
      'submit_feedback',
      params: {
        'p_category': category,
        'p_message': message,
        'p_app_build': appBuild,
        'p_platform': platform,
      },
    );
    return result as String;
  }
}
