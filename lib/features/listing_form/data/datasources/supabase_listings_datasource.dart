import 'package:decimal/decimal.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/listing/listing_columns.dart';
import '../../../../core/listing/listing_coordinates_reader.dart';
import '../../domain/entities/submit_failure.dart';
import '../dtos/listing_details_dto.dart';
import '../dtos/listing_dto.dart';
import '../dtos/listing_price_dto.dart';
import '../dtos/submit_listing_response_dto.dart';

@injectable
class SupabaseListingsDatasource {
  SupabaseListingsDatasource(this._coordinates);

  /// SEC-I1: exact coordinates no longer come back with the row — they are
  /// fetched through the owner/admin-gated `get_listing_coordinates` RPC and
  /// merged back under the same keys, so [ListingDto.fromMap] is unchanged.
  final ListingCoordinatesReader _coordinates;

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  Future<ListingDto?> findDraftForPublisher(String publisherUserId) async {
    final rows = await _client
        .from('listings')
        // SEC-I1: `.select()` (= `select=*`) would now 42501 — latitude and
        // longitude are no longer granted to `authenticated`.
        .select(listingColumnsWithoutCoordinates)
        .eq('publisher_user_id', publisherUserId)
        .eq('status', 'draft')
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first);
    await _coordinates.mergeInto(row, listingId: row['id'] as String);
    return ListingDto.fromMap(row);
  }

  Future<ListingDto?> loadListing(String listingId) async {
    final rows = await _client
        .from('listings')
        .select(listingColumnsWithoutCoordinates) // SEC-I1 — see above.
        .eq('id', listingId)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first);
    await _coordinates.mergeInto(row, listingId: listingId);
    return ListingDto.fromMap(row);
  }

  Future<ListingDto> insertDraft(String publisherUserId) async {
    // Drafts are partial-by-design: purpose/property_type/title are NULL on
    // INSERT (DB schema allows it per migration 20260519120011) and the
    // submit_listing RPC's Q1 validation catches missing fields at submit
    // time. The other NOT-NULL columns DO have DEFAULTs: status='draft',
    // location_visibility='approximate', contact_name_visibility='public',
    // created_at=now(), updated_at=now().
    //
    // SEC-I1: the projection also drives the INSERT's RETURNING clause, so a
    // bare `.select()` here would 42501 exactly like a read would. A fresh
    // draft has no coordinates yet, so nothing has to be merged back.
    final row = await _client
        .from('listings')
        .insert(<String, dynamic>{'publisher_user_id': publisherUserId})
        .select(listingColumnsWithoutCoordinates)
        .single();
    return ListingDto.fromMap(Map<String, dynamic>.from(row));
  }

  Future<ListingDetailsDto?> loadDetails(String listingId) async {
    final rows = await _client
        .from('listing_details')
        .select()
        .eq('listing_id', listingId)
        .limit(1);
    if (rows.isEmpty) return null;
    return ListingDetailsDto.fromMap(Map<String, dynamic>.from(rows.first));
  }

  Future<ListingPriceDto?> loadPrimaryPrice(String listingId) async {
    final rows = await _client
        .from('listing_prices')
        .select()
        .eq('listing_id', listingId)
        .eq('is_primary', true)
        .limit(1);
    if (rows.isEmpty) return null;
    return ListingPriceDto.fromMap(Map<String, dynamic>.from(rows.first));
  }

  Future<void> updateListing(
    String listingId,
    Map<String, dynamic> fields,
  ) async {
    if (fields.isEmpty) return;
    await _client.from('listings').update(fields).eq('id', listingId);
  }

  Future<void> upsertListingDetails({
    required String listingId,
    String? description,
    List<String> amenities = const <String>[],
    int? yearBuilt,
    bool? furnished,
    bool? parking,
  }) async {
    await _client.from('listing_details').upsert(<String, dynamic>{
      'listing_id': listingId,
      if (description != null) 'description': description,
      'amenities': amenities,
      if (yearBuilt != null) 'year_built': yearBuilt,
      if (furnished != null) 'furnished': furnished,
      if (parking != null) 'parking': parking,
    }, onConflict: 'listing_id');
  }

  /// Q3 single-currency invariant. If a row for this listing already exists
  /// with a different currency_code, DELETE it first (the
  /// `UNIQUE(listing_id, currency_code)` constraint would otherwise create
  /// a second row). Then UPSERT.
  Future<void> upsertListingPrice({
    required String listingId,
    required String currencyCode,
    required Decimal amount,
  }) async {
    final existing = await _client
        .from('listing_prices')
        .select('id, currency_code')
        .eq('listing_id', listingId)
        .limit(1);
    if (existing.isNotEmpty &&
        existing.first['currency_code'] != currencyCode) {
      await _client.from('listing_prices').delete().eq('listing_id', listingId);
    }
    await _client.from('listing_prices').upsert(<String, dynamic>{
      'listing_id': listingId,
      'currency_code': currencyCode,
      'amount': amount.toString(),
      'is_primary': true,
    }, onConflict: 'listing_id,currency_code');
  }

  /// Calls the SECURITY DEFINER RPC. Per `contracts/submit-listing-rpc.md`,
  /// SQLSTATE 22023 with a `missing_fields` JSON DETAIL → typed failure.
  Future<SubmitListingSuccessDto> submitListing(String listingId) async {
    try {
      final dynamic raw = await _client.rpc(
        'submit_listing',
        params: <String, dynamic>{'p_listing_id': listingId},
      );
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      if (map.isEmpty) {
        throw const FormatException(
          'submit_listing returned an empty response',
        );
      }
      final dto = SubmitListingResponseDto.fromSuccessJson(map);
      return dto as SubmitListingSuccessDto;
    } on supabase.PostgrestException catch (e) {
      final code = e.code ?? '';
      if (code == '22023') {
        final failureDto = SubmitListingResponseDto.fromFailureDetails(
          sqlState: code,
          details: e.details?.toString(),
          message: e.message,
        );
        throw SubmitListingFailureException(
          missingFields: failureDto.missingFields,
          sqlState: code,
          message: e.message,
        );
      }
      rethrow;
    }
  }

  /// Deletes one of the caller's own listings — a **soft** delete through the
  /// owner-gated `set_own_listing_status` RPC (plan A15).
  ///
  /// This used to be a bare `delete().eq('id', …)`, and for an ordinary
  /// publisher it did nothing at all: `listings` has exactly one DELETE policy,
  /// `listings_delete_admin`, gated on `listings.delete_any`. A PostgREST delete
  /// that matches no row is not an error — zero rows, 2xx — so the call returned
  /// normally, `ListingFormBloc` reset the form as though the draft were gone,
  /// and it reappeared in My Listings on the next load. Both drafts in
  /// production belong to staff who hold `delete_any`, which is why it had never
  /// been noticed (review 2026-09-04, M2).
  ///
  /// The RPC checks ownership and the transition, raises on refusal, and marks
  /// the row `deleted` rather than removing it — the same terminal status
  /// `request_account_deletion` uses, so the media stays reachable for the purge
  /// job and the audit trail survives.
  Future<void> deleteListing(String listingId) async {
    await _client.rpc<dynamic>(
      'set_own_listing_status',
      params: {'p_listing_id': listingId, 'p_status': 'deleted'},
    );
  }
}
