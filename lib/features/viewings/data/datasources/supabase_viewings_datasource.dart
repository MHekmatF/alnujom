// lib/features/viewings/data/datasources/supabase_viewings_datasource.dart
//
// Viewing scheduler — Supabase I/O for the viewings feature.
//
// Principle IX: sole importer of `package:supabase_flutter` under
// `lib/features/viewings/`. All table/RPC names are string-keyed so the project
// compiles without the DB applied.
//
// Operations:
//   - `from('viewings')` select joined w/ listing title (RLS-scoped to members)
//   - `rpc('request_viewing')` create a viewing request (publisher derived)
//   - `rpc('update_viewing_status')` confirm/decline/cancel

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/viewing_dto.dart';
import '../../domain/entities/viewing.dart' show kViewingsPageSize;

@injectable
class SupabaseViewingsDatasource {
  SupabaseViewingsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// The id of the signed-in user, or `null` when signed out. Used by the
  /// mapping layer to compute `amIPublisher`.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Embedded-selects projection: the viewing columns plus the listing heading,
  /// property type, public contact numbers and primary price (LEFT JOIN — the
  /// «معايناتي» card renders the price line + call/WhatsApp footer from these).
  static const String _viewingSelect =
      'id, listing_id, publisher_user_id, scheduled_at, status, note, '
      'listing:listings(title, property_type, phone, whatsapp, '
      'listing_prices(amount, currency_code, is_primary))';

  /// Loads every viewing the caller participates in (RLS scopes it to rows
  /// where auth.uid() is the requester or publisher), newest-first.
  Future<List<ViewingDto>> listMyViewings({
    DateTime? before,
    int limit = kViewingsPageSize,
  }) async {
    var query = _client.from('viewings').select(_viewingSelect);
    // Plan A36 — keyset paging: everything scheduled before the last row shown.
    if (before != null) {
      query = query.lt('scheduled_at', before.toUtc().toIso8601String());
    }
    final rows = await query
        .order('scheduled_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((r) => ViewingDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Creates a viewing request for [listingId] at [scheduledAtUtc] (UTC), with
  /// an optional [note]. The DB derives the publisher and errors on self.
  /// Returns the new viewing's id.
  Future<String> requestViewing({
    required String listingId,
    required DateTime scheduledAtUtc,
    String? note,
  }) async {
    final result = await _client.rpc(
      'request_viewing',
      params: {
        'p_listing_id': listingId,
        'p_scheduled_at': scheduledAtUtc.toUtc().toIso8601String(),
        'p_note': note,
      },
    );
    return result as String;
  }

  /// Transitions [viewingId] to [status] (confirmed/declined/cancelled). The DB
  /// enforces who may set which status.
  Future<void> updateStatus({
    required String viewingId,
    required String status,
  }) async {
    await _client.rpc(
      'update_viewing_status',
      params: {'p_viewing_id': viewingId, 'p_status': status},
    );
  }
}
