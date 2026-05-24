import 'dart:ui' show Locale;

import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/listing/rejection_reason.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../../../listing_form/data/dtos/listing_details_dto.dart';
import '../../../../listing_form/data/dtos/listing_dto.dart';
import '../../../../listing_form/data/dtos/listing_media_dto.dart';
import '../../../../listing_form/data/dtos/listing_price_dto.dart';
import '../../../../locations/data/dtos/area_dto.dart';
import '../../../../locations/data/dtos/city_dto.dart';
import '../../../../locations/data/dtos/governorate_dto.dart';
import '../../domain/entities/listing_preview.dart';
import '../../domain/entities/pending_listing_summary.dart';
import '../../domain/repositories/listing_review_repository.dart';
import '../datasources/supabase_listing_review_datasource.dart';

/// Phase 12 (spec/012-listing-approval) — concrete implementation of
/// `ListingReviewRepository`. Maps the Edge Function HTTP error envelope
/// (per `contracts/phase12-approve-listing-edge-function.md`) onto the
/// typed `Failure` subtypes (R-52).
@LazySingleton(as: ListingReviewRepository)
class ListingReviewRepositoryImpl implements ListingReviewRepository {
  ListingReviewRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'ListingReviewRepositoryImpl';

  final SupabaseListingReviewDatasource _datasource;
  final AppLogger _logger;

  /// Locale used to localize nested governorate/city/area display names.
  /// Phase 3 ships with a fixed `en` default to keep the BLoC + repository
  /// Constitution-IX clean (no Flutter widget imports); a future
  /// enhancement may inject a Locale provider so the queue + preview pages
  /// render names in the active locale.
  static const Locale _defaultLocale = Locale('en');

  // ─── loadPendingQueue ──────────────────────────────────────────────────

  @override
  Future<Result<List<PendingListingSummary>>> loadPendingQueue({
    PendingQueueCursor? cursor,
    int limit = 20,
  }) async {
    try {
      final dtos = await _datasource.loadPendingQueue(
        cursorCreatedAt: cursor?.lastSubmittedAt,
        cursorId: cursor?.lastId,
        limit: limit,
      );
      final entities = dtos
          .map((dto) => dto.toEntity(locale: _defaultLocale))
          .toList(growable: false);
      return Success(entities);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'loadPendingQueue failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  // ─── loadListingPreview ────────────────────────────────────────────────

  @override
  Future<Result<ListingPreview>> loadListingPreview(String listingId) async {
    try {
      final raw = await _datasource.loadListingPreview(listingId);
      if (raw == null) {
        return const FailureResult(UnknownFailure('Listing not found.'));
      }

      final listing = ListingDto.fromMap(raw).toEntity();

      // listing_details: nested-select returns a list with at most 1 row.
      final detailsRaw = raw['listing_details'];
      final details = detailsRaw is List && detailsRaw.isNotEmpty
          ? ListingDetailsDto.fromMap(
              Map<String, dynamic>.from(detailsRaw.first as Map),
            ).toEntity()
          : null;

      // prices: array of rows.
      final pricesRaw = raw['prices'];
      final prices = pricesRaw is List
          ? pricesRaw
                .map(
                  (p) => ListingPriceDto.fromMap(
                    Map<String, dynamic>.from(p as Map),
                  ).toEntity(),
                )
                .toList()
          : <dynamic>[];

      // media: array of rows.
      final mediaRaw = raw['media'];
      final media = mediaRaw is List
          ? mediaRaw
                .map(
                  (m) => ListingMediaDto.fromJson(
                    Map<String, dynamic>.from(m as Map),
                  ).toEntity(),
                )
                .toList()
          : <dynamic>[];

      // governorate / city / area: single nested row (or null if FK is null).
      final governorateRaw = raw['governorate'];
      final governorate = governorateRaw is Map
          ? GovernorateDto.fromJson(
              Map<String, dynamic>.from(governorateRaw),
            ).toEntity()
          : null;

      final cityRaw = raw['city'];
      final city = cityRaw is Map
          ? CityDto.fromJson(Map<String, dynamic>.from(cityRaw)).toEntity()
          : null;

      final areaRaw = raw['area'];
      final area = areaRaw is Map
          ? AreaDto.fromJson(Map<String, dynamic>.from(areaRaw)).toEntity()
          : null;

      final publisherRaw = raw['publisher'];
      String publisherDisplay = '—';
      if (publisherRaw is Map) {
        final fullName = publisherRaw['full_name']?.toString().trim();
        final phone = publisherRaw['phone']?.toString().trim();
        if (fullName != null && fullName.isNotEmpty) {
          publisherDisplay = fullName;
        } else if (phone != null && phone.isNotEmpty) {
          publisherDisplay = phone;
        }
      }

      return Success(
        ListingPreview(
          listing: listing,
          details: details,
          // Cast back to the concrete type list (the map preserves the
          // domain-entity type but `growable` defaults make it dynamic).
          prices: List.from(prices),
          media: List.from(media),
          governorate: governorate,
          city: city,
          area: area,
          publisherDisplayName: publisherDisplay,
        ),
      );
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'loadListingPreview failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  // ─── approveListing ────────────────────────────────────────────────────

  @override
  Future<Result<ApproveResult>> approveListing(String listingId) async {
    try {
      final response = await _datasource.approveListing(listingId);
      final status = response.status;
      final data = response.data;

      if (status == 200 && data is Map) {
        final publishedAtRaw = data['published_at'];
        final expiresAtRaw = data['expires_at'];
        if (publishedAtRaw is! String) {
          return const FailureResult(
            UnknownFailure('approve_listing: missing published_at'),
          );
        }
        return Success(
          ApproveResult(
            publishedAt: DateTime.parse(publishedAtRaw),
            expiresAt: expiresAtRaw is String
                ? DateTime.parse(expiresAtRaw)
                : null,
          ),
        );
      }

      return FailureResult(_mapEdgeFunctionError(status, data));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'approveListing failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  // ─── rejectListing ─────────────────────────────────────────────────────

  @override
  Future<Result<RejectResult>> rejectListing(
    String listingId,
    RejectionReason preset,
    String? detail,
  ) async {
    try {
      final response = await _datasource.rejectListing(
        listingId,
        preset,
        detail,
      );
      final status = response.status;
      final data = response.data;

      if (status == 200 && data is Map) {
        final presetKey = data['reason_preset']?.toString();
        if (presetKey == null) {
          return const FailureResult(
            UnknownFailure('reject_listing: missing reason_preset'),
          );
        }
        final returnedDetailRaw = data['reason_detail'];
        final returnedDetail = returnedDetailRaw is String
            ? returnedDetailRaw
            : null;
        final RejectionReason returnedPreset;
        try {
          returnedPreset = RejectionReason.fromKey(presetKey);
        } on ArgumentError {
          return FailureResult(
            UnknownFailure('reject_listing: unknown preset $presetKey'),
          );
        }
        return Success(
          RejectResult(preset: returnedPreset, detail: returnedDetail),
        );
      }

      return FailureResult(_mapEdgeFunctionError(status, data));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'rejectListing failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  // ─── Edge Function error mapping (R-52) ───────────────────────────────

  Failure _mapEdgeFunctionError(int httpStatus, dynamic data) {
    final code = data is Map ? data['code']?.toString() : null;

    switch (code) {
      case 'permission_denied':
        return const PermissionDeniedFailure();
      case 'invalid_status_transition':
        final cs = data is Map ? data['current_status']?.toString() : null;
        return InvalidStatusTransitionFailure(currentStatus: cs ?? 'unknown');
      case 'already_acted_on':
        final cs = data is Map ? data['current_status']?.toString() : null;
        return AlreadyActedOnFailure(currentStatus: cs ?? 'approved');
      case 'invalid_reason_preset':
        return const InvalidReasonPresetFailure();
      case 'reason_detail_too_long':
        final max = data is Map ? data['max'] : null;
        return ReasonDetailTooLongFailure(max: max is int ? max : 500);
      case 'listing_not_found':
        return const UnknownFailure('listing_not_found');
      case 'invalid_listing_id':
      case 'invalid_request':
        return const UnknownFailure('invalid_request');
      default:
        return UnknownFailure(
          'edge_function_error: http=$httpStatus code=$code',
        );
    }
  }
}
