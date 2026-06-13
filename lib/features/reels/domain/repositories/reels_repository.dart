import 'dart:ui' show Locale;

import '../../../../core/errors/result.dart';
import '../entities/reel.dart';

/// Phase 029 (Reels W4) — abstract contract for the public-read reels feed.
///
/// Keyset pagination over `(published_at, id)` DESC: pass `before: null` for
/// the first page, then `before: ReelCursor.fromLast(reels.last)` for each
/// subsequent page. Returns:
/// - `Success([])` → end of feed (or no reels at all → the rail/feed hide
///   themselves).
/// - `Success(rows)` where `rows.length < limit` → end reached this page.
/// - `Success(rows)` where `rows.length == limit` → more pages may exist.
/// - `FailureResult(NetworkFailure(...))` → transport error (the rail hides
///   itself; reels are a non-blocking enhancement).
///
/// RLS is the sole authorization filter; `locale` is consumed at DTO→entity
/// mapping to resolve the localized location label.
abstract class ReelsRepository {
  Future<Result<List<Reel>>> fetchPage({
    int limit = 10,
    ReelCursor? before,
    required Locale locale,
  });
}

/// Opaque `(published_at, id)` keyset cursor for the reels feed. Lives only in
/// cubit state — never persisted, never in a URL.
class ReelCursor {
  const ReelCursor({required this.publishedAt, required this.id});

  ReelCursor.fromLast(Reel last)
    : publishedAt = last.publishedAt,
      id = last.listingId;

  final DateTime publishedAt;
  final String id;
}
