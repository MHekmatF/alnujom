import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/listing_details_aggregate.dart';
import '../../domain/repositories/listing_details_repository.dart';
import '../datasources/supabase_listing_details_datasource.dart';

/// Phase 13 (spec/013-home-and-details) — concrete implementation of
/// [ListingDetailsRepository].
///
/// Maps datasource responses to domain results:
/// - `null` from datasource → `FailureResult(ListingNotFoundFailure())` per
///   FR-024 (RLS-hidden and genuinely non-existent are indistinguishable per
///   Constitution III).
/// - Network/PostgREST exceptions → `FailureResult(NetworkFailure(...))`.
@LazySingleton(as: ListingDetailsRepository)
class ListingDetailsRepositoryImpl implements ListingDetailsRepository {
  const ListingDetailsRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'ListingDetailsRepositoryImpl';

  final SupabaseListingDetailsDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<ListingDetailsAggregate>> fetchListing(String id) async {
    try {
      final dto = await _datasource.fetchListing(id);
      if (dto == null) {
        return const FailureResult(ListingNotFoundFailure());
      }
      return Success(dto.toEntity());
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchListing failed for id=$id',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        NetworkFailure(
          error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
