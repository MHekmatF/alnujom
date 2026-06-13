import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/repositories/reels_repository.dart' show ReelCursor;
import '../dtos/reel_dto.dart';

/// Phase 029 (Reels W4) — sole importer of `package:supabase_flutter` under
/// `lib/features/reels/` (Constitution IX).
///
/// Invokes the `list_video_reels` SECURITY DEFINER RPC (keyset-paginated over
/// `(published_at, id)` DESC) and parses each row into a [ReelDto]. Public
/// storage URLs are resolved later in [ReelDto.toEntity] via
/// [ReelsStorageUrlResolver].
@injectable
class SupabaseReelsDatasource {
  SupabaseReelsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Fetches one keyset page. Pass [before] = null for the first page; pass a
  /// [ReelCursor] derived from the last reel for subsequent pages.
  Future<List<ReelDto>> fetchPage({int limit = 10, ReelCursor? before}) async {
    final result = await _client.rpc(
      'list_video_reels',
      params: <String, dynamic>{
        'p_limit': limit,
        'p_before_published_at': before?.publishedAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
      },
    );

    final rows = result as List<dynamic>;
    return rows
        .map((r) => ReelDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
