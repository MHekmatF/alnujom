import '../../../../core/errors/result.dart';
import '../entities/listing_details_aggregate.dart';

/// Phase 13 (spec/013-home-and-details) — abstract repository for the
/// listing-details feature.
///
/// Returns [ListingNotFoundFailure] when:
/// - The row is RLS-hidden (listing status != 'approved' for anonymous callers)
/// - The row genuinely doesn't exist (invalid UUID)
///
/// Per Constitution III the two cases are intentionally indistinguishable —
/// an attacker probing UUIDs MUST NOT be able to tell which exist-but-hidden
/// vs don't-exist. The [ListingNotFoundFailure] type is declared in
/// `lib/core/errors/failure.dart` per R-68.
abstract class ListingDetailsRepository {
  Future<Result<ListingDetailsAggregate>> fetchListing(String id);
}
