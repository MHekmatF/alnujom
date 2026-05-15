import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/session.dart';

/// Maps Supabase's session shape to the domain [Session] entity.
/// Constitution IX boundary: this is data-layer-only.
extension SupabaseSessionMapper on supabase.Session {
  Session toDomain() => Session(
    userId: user.id,
    isActive: !_isExpired,
    expiresAt: expiresAt != null
        ? DateTime.fromMillisecondsSinceEpoch(expiresAt! * 1000, isUtc: true)
        : null,
  );

  bool get _isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    final expiryMs = exp * 1000;
    return DateTime.now().toUtc().millisecondsSinceEpoch > expiryMs;
  }
}
