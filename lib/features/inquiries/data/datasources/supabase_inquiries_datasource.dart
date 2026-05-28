// lib/features/inquiries/data/datasources/supabase_inquiries_datasource.dart
//
// Phase 16 — SOLE importer of the supabase_flutter package under
// `lib/features/inquiries/` per Constitution IX.
//
// All Supabase I/O for the inquiries + lead_events features:
//   - submit_inquiry RPC (FR-009)
//   - v_inquiries_inbox view queries (FR-013, FR-015)
//   - inquiries table UPDATE (status mutation, FR-021a)
//   - get_inbox_unread_count RPC (FR-016 badge)
//   - record_lead_event RPC (FR-002, FR-004)
//   - v_lead_events_publisher / v_lead_events_admin view queries (FR-014b)

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/inquiry_status.dart';
import '../../domain/entities/inquiry_submission.dart';
import '../../domain/entities/lead_event_type.dart';
import '../models/inquiry_dto.dart';
import '../models/lead_event_dto.dart';

/// Tier for [loadLeadEventsByListing] — determines which Supabase view to query.
enum LeadEventTier { publisher, admin }

@injectable
class SupabaseInquiriesDatasource {
  SupabaseInquiriesDatasource(this._client);

  final supabase.SupabaseClient _client;

  // ---------------------------------------------------------------------------
  // Inquiry operations
  // ---------------------------------------------------------------------------

  /// Calls `submit_inquiry` RPC. Returns the new inquiry UUID.
  Future<String> submitInquiry(InquirySubmission submission) async {
    final result = await _client.rpc('submit_inquiry', params: {
      'p_listing_id': submission.listingId,
      'p_sender_name': submission.senderName,
      'p_inquirer_phone': submission.phone,
      'p_message': submission.message,
    });
    return result as String;
  }

  /// Queries `v_inquiries_inbox` with optional filters + cursor pagination.
  ///
  /// Ordering: newest-first by (created_at DESC, id DESC).
  /// [cursor] is an ISO-8601 timestamp used as an upper bound (keyset pagination).
  Future<List<InquiryDto>> loadInbox({
    InquiryStatus? statusFilter,
    String? listingIdFilter,
    String? cursor,
    int limit = 30,
  }) async {
    var query = _client.from('v_inquiries_inbox').select();

    if (cursor != null) {
      query = query.lt('created_at', cursor);
    }
    if (statusFilter != null) {
      query = query.eq('status', statusFilter.wireValue);
    }
    if (listingIdFilter != null) {
      query = query.eq('listing_id', listingIdFilter);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((row) => InquiryDto.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Queries `v_inquiries_inbox` for a single row by id.
  Future<InquiryDto?> loadDetail(String id) async {
    final row = await _client
        .from('v_inquiries_inbox')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return InquiryDto.fromJson(Map<String, dynamic>.from(row));
  }

  /// Updates `status` on the `inquiries` table.
  ///
  /// Throws [supabase.PostgrestException] when the transition trigger rejects
  /// the mutation (SQLSTATE 23514 / message containing 'invalid_inquiry_transition').
  /// The repository layer maps this to [TransitionInvalidFailure].
  Future<void> updateStatus(String id, InquiryStatus newStatus) async {
    await _client
        .from('inquiries')
        .update({'status': newStatus.wireValue})
        .eq('id', id);
  }

  /// Calls `get_inbox_unread_count` RPC. Returns the integer badge count.
  Future<int> loadUnreadCount() async {
    final result = await _client.rpc('get_inbox_unread_count');
    return (result as num).toInt();
  }

  /// Calls `publisher_owns_approved_listing` RPC. Drives the home inbox-entry
  /// visibility gate (FR-019 / Q6=B) — true when the caller owns ≥ 1 approved
  /// listing, independent of unread count.
  Future<bool> ownsApprovedListing() async {
    final result = await _client.rpc('publisher_owns_approved_listing');
    return result as bool? ?? false;
  }

  // ---------------------------------------------------------------------------
  // Lead-event operations
  // ---------------------------------------------------------------------------

  /// Calls `record_lead_event` RPC. Returns the new lead event UUID.
  Future<String> recordLeadEvent({
    required String listingId,
    required LeadEventType eventType,
  }) async {
    final result = await _client.rpc('record_lead_event', params: {
      'p_listing_id': listingId,
      'p_event_type': eventType.wireValue,
    });
    return result as String;
  }

  /// Queries either `v_lead_events_publisher` (default) or `v_lead_events_admin`
  /// based on [tier]. Optionally filters to events created after [since].
  Future<List<LeadEventDto>> loadLeadEventsByListing(
    String listingId, {
    required LeadEventTier tier,
    DateTime? since,
  }) async {
    final viewName = tier == LeadEventTier.admin
        ? 'v_lead_events_admin'
        : 'v_lead_events_publisher';

    var query = _client.from(viewName).select().eq('listing_id', listingId);

    if (since != null) {
      query = query.gte('created_at', since.toIso8601String());
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => LeadEventDto.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}
