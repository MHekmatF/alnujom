// lib/features/inquiries/data/repositories/lead_event_repository_impl.dart
//
// Phase 16 — concrete [LeadEventRepository] delegating to
// [SupabaseInquiriesDatasource]. Wraps exceptions in typed [Failure] values
// per the Phase 14/15 pattern.
//
// Per Constitution IX this file MUST NOT import the supabase_flutter package
// — the datasource is the sole importer.
import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/lead_event.dart';
import '../../domain/entities/lead_event_type.dart';
import '../../domain/repositories/lead_event_repository.dart';
import '../datasources/supabase_inquiries_datasource.dart';

@Injectable(as: LeadEventRepository)
class LeadEventRepositoryImpl implements LeadEventRepository {
  LeadEventRepositoryImpl(this._datasource);

  final SupabaseInquiriesDatasource _datasource;

  @override
  Future<Result<String>> recordEvent({
    required String listingId,
    required LeadEventType eventType,
  }) async {
    try {
      final id = await _datasource.recordLeadEvent(
        listingId: listingId,
        eventType: eventType,
      );
      return Success(id);
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('recordEvent failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<LeadEvent>>> loadByListing(
    String listingId, {
    DateTime? since,
  }) async {
    try {
      // The RLS policy on v_lead_events_admin gates non-admins via the view
      // predicate. Default to publisher tier; the view access (admin vs publisher)
      // is governed by RLS and the caller's permissions at the Supabase layer.
      // Use publisher tier as the default — admin-tier callers can reach
      // v_lead_events_admin via the permission gate inside the view itself.
      final dtos = await _datasource.loadLeadEventsByListing(
        listingId,
        tier: LeadEventTier.publisher,
        since: since,
      );
      return Success(dtos.map((d) => d.toEntity()).toList());
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadByListing failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
