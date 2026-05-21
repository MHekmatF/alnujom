import 'package:decimal/decimal.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/submit_failure.dart';
import '../dtos/listing_details_dto.dart';
import '../dtos/listing_dto.dart';
import '../dtos/listing_price_dto.dart';
import '../dtos/submit_listing_response_dto.dart';

@injectable
class SupabaseListingsDatasource {
  SupabaseListingsDatasource();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  Future<ListingDto?> findDraftForPublisher(String publisherUserId) async {
    final rows = await _client
        .from('listings')
        .select()
        .eq('publisher_user_id', publisherUserId)
        .eq('status', 'draft')
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return ListingDto.fromMap(Map<String, dynamic>.from(rows.first));
  }

  Future<ListingDto?> loadListing(String listingId) async {
    final rows = await _client
        .from('listings')
        .select()
        .eq('id', listingId)
        .limit(1);
    if (rows.isEmpty) return null;
    return ListingDto.fromMap(Map<String, dynamic>.from(rows.first));
  }

  Future<ListingDto> insertDraft(String publisherUserId) async {
    // Drafts are partial-by-design: purpose/property_type/title are NULL on
    // INSERT (DB schema allows it per migration 20260519120011) and the
    // submit_listing RPC's Q1 validation catches missing fields at submit
    // time. The other NOT-NULL columns DO have DEFAULTs: status='draft',
    // location_visibility='approximate', contact_name_visibility='public',
    // created_at=now(), updated_at=now().
    final row = await _client
        .from('listings')
        .insert(<String, dynamic>{'publisher_user_id': publisherUserId})
        .select()
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

  Future<void> deleteListing(String listingId) async {
    await _client.from('listings').delete().eq('id', listingId);
  }
}
