// Plan A29 — blocking a person. Every call lands on a SECURITY DEFINER RPC
// (`block_user`, `unblock_user`, `is_user_blocked_by_me`, `list_my_blocks`);
// the table itself has no client grants. Zero Supabase imports here
// (Constitution IX).
import '../../../../core/errors/result.dart';
import '../entities/blocked_user.dart';

abstract interface class UserBlocksRepository {
  /// Blocks [userId]. Idempotent server-side.
  Future<Result<void>> block(String userId);

  /// Removes the block on [userId]. Succeeds even when none existed.
  Future<Result<void>> unblock(String userId);

  /// Whether the signed-in user has blocked [userId].
  Future<Result<bool>> isBlocked(String userId);

  /// Everyone the signed-in user has blocked, newest first.
  Future<Result<List<BlockedUser>>> listBlocked();
}
