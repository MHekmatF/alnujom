// lib/core/listing/listing_coordinates_reader.dart
//
// SEC-I1 (docs/qa/e2e-2026-07-16/SECURITY_AUDIT.md) — the single client-side
// path to a listing's EXACT coordinates.
//
// `latitude` / `longitude` are no longer SELECT-able from `public.listings` by
// `anon` or `authenticated` (migration
// `20260901120002_revoke_authenticated_listing_coordinates.sql`). The only way a
// client can still read them is the `get_listing_coordinates` SECURITY DEFINER
// RPC, which returns the pair when the caller OWNS the listing or holds
// `listings.view_all`, and NULL otherwise — the same NULL a missing listing
// returns, so it is not an existence oracle.
//
// Shared by the three owner/admin surfaces that used to read the raw columns:
// the listing edit form, the admin revision diff and the admin listing preview.
//
// Failures are swallowed into `null` on purpose: a listing simply has no
// coordinate the caller may see. Callers must already handle a coordinate-less
// listing (a fresh draft has none), so a network blip degrades to the same,
// already-supported state instead of failing the whole screen.

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../logging/app_logger.dart';

/// The exact `(latitude, longitude)` of one listing, as returned by the
/// owner/admin-gated RPC. Both values are non-null; a listing with only one of
/// the two stored resolves to `null` instead of a half-filled pair.
class ListingCoordinates {
  const ListingCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

@lazySingleton
class ListingCoordinatesReader {
  ListingCoordinatesReader(this._logger);

  static const String _tag = 'ListingCoordinates';

  final AppLogger _logger;

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  /// Returns the listing's exact coordinates when the signed-in caller owns it
  /// or can moderate it; `null` for everyone else, for a listing that has no
  /// coordinates stored, and on any transport error.
  Future<ListingCoordinates?> read(String listingId) async {
    try {
      final dynamic raw = await _client.rpc<dynamic>(
        'get_listing_coordinates',
        params: <String, dynamic>{'p_listing_id': listingId},
      );
      if (raw is! Map) return null;
      final lat = _doubleOrNull(raw['latitude']);
      final lng = _doubleOrNull(raw['longitude']);
      if (lat == null || lng == null) return null;
      return ListingCoordinates(latitude: lat, longitude: lng);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'get_listing_coordinates failed; continuing without coordinates.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return null;
    }
  }

  /// Merges the caller-visible coordinates into a raw `listings` row map under
  /// the same `latitude` / `longitude` keys the row used to carry, so existing
  /// DTO factories keep working unchanged. Leaves the keys absent when the
  /// caller may not see them.
  Future<void> mergeInto(
    Map<String, dynamic> listingRow, {
    required String listingId,
  }) async {
    final coordinates = await read(listingId);
    if (coordinates == null) return;
    listingRow['latitude'] = coordinates.latitude;
    listingRow['longitude'] = coordinates.longitude;
  }

  static double? _doubleOrNull(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }
}
