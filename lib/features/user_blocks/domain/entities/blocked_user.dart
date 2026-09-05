// Plan A29 — a person the signed-in user has blocked. Projection of the
// `list_my_blocks()` RPC row. Zero Supabase imports (Constitution IX).
import 'package:equatable/equatable.dart';

class BlockedUser extends Equatable {
  const BlockedUser({
    required this.userId,
    required this.blockedAt,
    this.fullName,
  });

  final String userId;

  /// May be null when the profile is gone; the UI shows a generic label.
  final String? fullName;

  final DateTime blockedAt;

  @override
  List<Object?> get props => [userId, fullName, blockedAt];
}
