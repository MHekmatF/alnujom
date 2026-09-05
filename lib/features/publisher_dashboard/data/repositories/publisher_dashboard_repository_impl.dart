import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/moderation_history_entry.dart';
import '../../domain/entities/publisher_listing.dart';
import '../../domain/repositories/publisher_dashboard_repository.dart';
import '../datasources/supabase_publisher_dashboard_datasource.dart';

@LazySingleton(as: PublisherDashboardRepository)
class PublisherDashboardRepositoryImpl implements PublisherDashboardRepository {
  PublisherDashboardRepositoryImpl(this._datasource);

  final SupabasePublisherDashboardDatasource _datasource;

  @override
  String? get currentUserId => _datasource.currentUserId;

  @override
  Future<List<PublisherListing>> listMyListings({
    ListingStatus? statusFilter,
    int offset = 0,
    int limit = 20,
  }) async {
    final dtos = await _datasource.listMyListings(
      statusFilter: statusFilter?.toDbValue(),
      offset: offset,
      limit: limit,
    );
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<Result<void>> setOwnListingStatus({
    required String listingId,
    required ListingStatus status,
  }) async {
    try {
      await _datasource.setOwnListingStatus(
        listingId: listingId,
        status: status.toDbValue(),
      );
      return const Success(null);
    } on Object catch (error, stackTrace) {
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<Result<DateTime?>> renewListing({
    required String listingId,
    int? days,
  }) async {
    try {
      final expiresAt = await _datasource.renewListing(
        listingId: listingId,
        days: days,
      );
      return Success(expiresAt);
    } on Object catch (error, stackTrace) {
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<Result<List<ModerationHistoryEntry>>> loadModerationHistory(
    String listingId,
  ) async {
    try {
      final entries = await _datasource.loadModerationHistory(listingId);
      return Success(entries);
    } on Object catch (error, stackTrace) {
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<Result<ModerationHistoryEntry?>> loadMostRecentRejection(
    String listingId,
  ) async {
    try {
      final entry = await _datasource.loadMostRecentRejection(listingId);
      return Success(entry);
    } on Object catch (error, stackTrace) {
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }
}
