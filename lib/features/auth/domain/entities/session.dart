import 'package:equatable/equatable.dart';

/// Provider-agnostic auth session (Phase 5 FR-011).
///
/// Wraps the existence/absence of an authenticated session + the linked user id.
/// Constitution IX: no Supabase types.
class Session extends Equatable {
  const Session({
    required this.userId,
    required this.isActive,
    this.expiresAt,
  });

  final String userId;
  final bool isActive;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [userId, isActive, expiresAt];
}
