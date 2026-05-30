// Phase 18 (spec/018-reports-moderation) — ReportsRepositoryImpl.
//
// Concrete [ReportsRepository] delegating to [SupabaseReportsDatasource].
// Wraps exceptions in typed [Failure] values per the Phase 14–17 pattern
// (SearchRepositoryImpl / MapRepositoryImpl / InquiryRepositoryImpl /
// FavoritesRepositoryImpl).
//
// Per Constitution IX this file MUST NOT import supabase_flutter directly
// beyond [PostgrestException] (typed error-code mapping only).
//
// RPC error-code → Failure mapping (submit_report SQLSTATE codes):
//   28000  auth_required          → PermissionDeniedFailure
//   22023  invalid_reason         → ValidationFailure('invalid_reason')
//   23503  listing_not_found      → ListingNotFoundFailure
//   23514  listing_not_approved   → ValidationFailure('listing_not_approved')
//   23505  already_reported       → ValidationFailure('already_reported')
//   Other PostgrestException      → UnknownFailure

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/report.dart';
import '../../domain/entities/report_reason.dart';
import '../../domain/repositories/reports_repository.dart';
import '../datasources/supabase_reports_datasource.dart';

@Injectable(as: ReportsRepository)
class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl(this._datasource);

  final SupabaseReportsDatasource _datasource;

  @override
  Future<Result<String>> submitReport(
    String listingId,
    ReportReason reason,
    String? note,
  ) async {
    try {
      final id = await _datasource.submitReport(
        listingId,
        reason.wireValue,
        note,
      );
      return Success(id);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'submitReport'));
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('submitReport failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<Report>>> loadMyReports({
    String? cursor,
    int limit = 30,
  }) async {
    try {
      final dtos = await _datasource.loadMyReports(
        cursor: cursor,
        limit: limit,
      );
      return Success(dtos.map((d) => d.toEntity()).toList());
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure(
          'loadMyReports failed: ${e.message}',
          cause: e,
          stackTrace: st,
        ),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadMyReports failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<Report?>> loadMyReportForListing(String listingId) async {
    try {
      final dto = await _datasource.loadMyReportForListing(listingId);
      return Success(dto?.toEntity());
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure(
          'loadMyReportForListing failed: ${e.message}',
          cause: e,
          stackTrace: st,
        ),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure(
          'loadMyReportForListing failed: $e',
          cause: e,
          stackTrace: st,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Maps submit_report RPC error codes (embedded in [e.message]) to typed
  /// [Failure] subtypes. Falls through to [UnknownFailure] for unrecognised codes.
  Failure _mapRpcError(PostgrestException e, StackTrace st, String context) {
    final msg = e.message;
    if (msg.contains('auth_required') || e.code == '28000') {
      return const PermissionDeniedFailure();
    }
    if (msg.contains('listing_not_found') || e.code == '23503') {
      return const ListingNotFoundFailure();
    }
    if (msg.contains('listing_not_approved') ||
        msg.contains('already_reported') ||
        msg.contains('invalid_reason') ||
        e.code == '23514' ||
        e.code == '23505' ||
        e.code == '22023') {
      // Extract the specific code from the message for localization.
      final code = _extractCode(msg);
      return ValidationFailure(code);
    }
    return UnknownFailure(
      '$context failed: ${e.message}',
      cause: e,
      stackTrace: st,
    );
  }

  /// Extracts a short error code key from a PostgrestException message.
  /// Falls back to the raw message if no known key is found.
  String _extractCode(String message) {
    const knownCodes = [
      'invalid_reason',
      'listing_not_approved',
      'already_reported',
    ];
    for (final code in knownCodes) {
      if (message.contains(code)) return code;
    }
    return message;
  }
}
