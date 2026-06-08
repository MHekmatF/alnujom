import 'dart:ui' show Locale;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/similar_listing_card.dart';
import '../../domain/repositories/similar_listings_repository.dart';
import '../datasources/supabase_similar_listings_datasource.dart';

/// Premium uplift v2 — concrete [SimilarListingsRepository].
///
/// Maps datasource rows to localized [SimilarListingCard]s. A network/PostgREST
/// failure surfaces as [NetworkFailure]; an empty pool is a [Success] with an
/// empty list (the carousel simply renders nothing).
@LazySingleton(as: SimilarListingsRepository)
class SimilarListingsRepositoryImpl implements SimilarListingsRepository {
  const SimilarListingsRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'SimilarListingsRepositoryImpl';

  final SupabaseSimilarListingsDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<List<SimilarListingCard>>> fetchSimilar({
    required String listingId,
    required String propertyType,
    String? governorateId,
    required Locale locale,
    int limit = 8,
  }) async {
    try {
      final dtos = await _datasource.fetchSimilar(
        listingId: listingId,
        propertyType: propertyType,
        governorateId: governorateId,
        limit: limit,
      );
      final cards = dtos
          .map((dto) => dto.toEntity(locale: locale))
          .toList(growable: false);
      return Success(cards);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchSimilar failed for id=$listingId',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        NetworkFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }
}
