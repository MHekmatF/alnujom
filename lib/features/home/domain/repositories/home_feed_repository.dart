import 'dart:ui' show Locale;

import '../../../../core/errors/result.dart';
import '../entities/cursor.dart';
import '../entities/home_listing_card.dart';

/// Phase 13 — abstract contract for the public-read home feed per FR-015.
///
/// Returns a `Result<List<HomeListingCard>>`:
/// - `Success([])` → end of feed (or empty seed).
/// - `Success(rows)` where `rows.length < 20` → end of feed reached at this page.
/// - `Success(rows)` where `rows.length == 20` → more pages may exist; next
///   page driven by `Cursor.fromLastCard(rows.last)`.
/// - `FailureResult(NetworkFailure(...))` → transport error.
///
/// RLS is the SOLE filter for `status='approved'` per FR-018. The
/// implementation MUST NOT add an application-layer `status='approved'`
/// filter.
abstract class HomeFeedRepository {
  /// Fetches one page of the home feed. Pass `cursor: null` for the first
  /// page or after a pull-to-refresh; pass `Cursor.fromLastCard(last)` for
  /// subsequent pages.
  ///
  /// `locale` is consumed at DTO→entity mapping to resolve the localized
  /// governorate/city names per the user's active locale per data-model.md
  /// §2.2.
  Future<Result<List<HomeListingCard>>> fetchPage({
    Cursor? cursor,
    required Locale locale,
  });
}
