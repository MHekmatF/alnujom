import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/publisher_rating.dart';
import '../../domain/entities/response_stats.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/review_failure.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../datasources/supabase_reviews_datasource.dart';

/// Concrete [ReviewsRepository].
///
/// Maps datasource rows to domain entities; a network/PostgREST failure surfaces
/// as [NetworkFailure], a unique-violation on insert as [AlreadyReviewedFailure].
@LazySingleton(as: ReviewsRepository)
class ReviewsRepositoryImpl implements ReviewsRepository {
  const ReviewsRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'ReviewsRepositoryImpl';
  static const _uniqueViolation = '23505';

  final SupabaseReviewsDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<List<Review>>> fetchReviews(
    String targetUserId, {
    int limit = 20,
  }) async {
    try {
      final dtos = await _datasource.fetchReviews(targetUserId, limit: limit);
      return Success(dtos.map((d) => d.toEntity()).toList(growable: false));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchReviews failed for target=$targetUserId',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        NetworkFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<Result<PublisherRating?>> fetchRating(String targetUserId) async {
    try {
      final dto = await _datasource.fetchRating(targetUserId);
      return Success(dto?.toEntity());
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchRating failed for target=$targetUserId',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        NetworkFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<Result<ResponseStats?>> fetchResponseStats(String targetUserId) async {
    try {
      final dto = await _datasource.fetchResponseStats(targetUserId);
      return Success(dto?.toEntity());
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchResponseStats failed for target=$targetUserId',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        NetworkFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<Result<void>> submitReview({
    required String targetUserId,
    String? listingId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _datasource.submitReview(
        targetUserId: targetUserId,
        listingId: listingId,
        rating: rating,
        comment: comment,
      );
      return const Success(null);
    } on supabase.PostgrestException catch (error, stackTrace) {
      if (error.code == _uniqueViolation) {
        _logger.info(
          'submitReview duplicate for target=$targetUserId',
          tag: _tag,
        );
        return const FailureResult(AlreadyReviewedFailure());
      }
      _logger.warning(
        'submitReview failed for target=$targetUserId',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        NetworkFailure(error.message, cause: error, stackTrace: stackTrace),
      );
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'submitReview failed for target=$targetUserId',
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
