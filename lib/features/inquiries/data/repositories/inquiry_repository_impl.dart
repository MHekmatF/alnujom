// lib/features/inquiries/data/repositories/inquiry_repository_impl.dart
//
// Phase 16 — concrete [InquiryRepository] delegating to
// [SupabaseInquiriesDatasource]. Wraps exceptions in typed [Failure] values
// per the Phase 14/15 SearchRepositoryImpl / MapRepositoryImpl pattern.
//
// Per Constitution IX this file MUST NOT import the supabase_flutter package
// — the datasource is the sole importer.
import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/inquiry_status.dart';
import '../../domain/entities/inquiry_submission.dart';
import '../../domain/repositories/inquiry_repository.dart';
import '../datasources/supabase_inquiries_datasource.dart';

@Injectable(as: InquiryRepository)
class InquiryRepositoryImpl implements InquiryRepository {
  InquiryRepositoryImpl(this._datasource);

  final SupabaseInquiriesDatasource _datasource;

  @override
  Future<Result<String>> submitInquiry(InquirySubmission submission) async {
    try {
      final id = await _datasource.submitInquiry(submission);
      return Success(id);
    } on PostgrestException catch (e, st) {
      // `submit_inquiry` grew an hourly ceiling on 2026-09-04 (20 per listing,
      // 10 per signed-in sender) so a script cannot flood a publisher's phone.
      // Surface it as its own code: without this it fell through to
      // UnknownFailure and the sheet showed the generic "couldn't send" toast,
      // which invites the immediate retry that hits the same ceiling again.
      if (e.code == '23514' && e.message.contains('rate_limited')) {
        return const FailureResult(ValidationFailure('rate_limited'));
      }
      return FailureResult(
        UnknownFailure(
          'submitInquiry failed: ${e.message}',
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
        UnknownFailure('submitInquiry failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<Inquiry>>> loadInbox({
    InquiryStatus? statusFilter,
    String? listingIdFilter,
    String? cursor,
    int limit = 30,
    bool adminTier = false,
  }) async {
    try {
      final dtos = await _datasource.loadInbox(
        statusFilter: statusFilter,
        listingIdFilter: listingIdFilter,
        cursor: cursor,
        limit: limit,
        adminTier: adminTier,
      );
      return Success(dtos.map((d) => d.toEntity()).toList());
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
        UnknownFailure('loadInbox failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<Inquiry>> loadDetail(String inquiryId) async {
    try {
      final dto = await _datasource.loadDetail(inquiryId);
      if (dto == null) {
        return const FailureResult(ListingNotFoundFailure());
      }
      return Success(dto.toEntity());
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
        UnknownFailure('loadDetail failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> updateStatus(
    String inquiryId,
    InquiryStatus newStatus,
  ) async {
    try {
      await _datasource.updateStatus(inquiryId, newStatus);
      return const Success(null);
    } on PostgrestException catch (e, st) {
      // SQLSTATE 23514 or message containing 'invalid_inquiry_transition'
      if (e.code == '23514' ||
          (e.message.contains('invalid_inquiry_transition'))) {
        return const FailureResult(TransitionInvalidFailure());
      }
      return FailureResult(
        UnknownFailure(
          'updateStatus failed: ${e.message}',
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
        UnknownFailure('updateStatus failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<int>> loadUnreadCount() async {
    try {
      final count = await _datasource.loadUnreadCount();
      return Success(count);
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
        UnknownFailure('loadUnreadCount failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<bool>> ownsApprovedListing() async {
    try {
      final owns = await _datasource.ownsApprovedListing();
      return Success(owns);
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
          'ownsApprovedListing failed: $e',
          cause: e,
          stackTrace: st,
        ),
      );
    }
  }
}
