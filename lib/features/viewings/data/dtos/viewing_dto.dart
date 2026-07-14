// lib/features/viewings/data/dtos/viewing_dto.dart
//
// Viewing scheduler — DTO mirroring a row from `public.viewings` joined with
// the listing title (for the list heading).
//
// Column layout (viewings):
//   id                  uuid (PK)
//   listing_id          uuid
//   requester_user_id   uuid (DB-defaulted to auth.uid())
//   publisher_user_id   uuid
//   scheduled_at        timestamptz
//   status              text in (requested|confirmed|declined|cancelled)
//   note                text
//   created_at          timestamptz
//   updated_at          timestamptz
//
// The datasource embeds `listing:listings(title)` so the list can render a
// heading without a second query. `amIPublisher` is computed in the mapping
// layer from the caller's user id (publisher_user_id == currentUserId).

import '../../../listing_form/domain/entities/listing.dart'
    show PropertyType, PropertyTypeDb;
import '../../domain/entities/viewing.dart';

/// DTO for a `public.viewings` row plus the embedded listing heading, contact
/// numbers, property type and primary price.
class ViewingDto {
  const ViewingDto({
    required this.id,
    required this.listingId,
    required this.publisherUserId,
    required this.scheduledAt,
    required this.status,
    this.listingTitle,
    this.note,
    this.propertyType,
    this.priceAmount,
    this.priceCurrency,
    this.publisherPhone,
    this.publisherWhatsapp,
  });

  final String id;
  final String listingId;
  final String publisherUserId;
  final DateTime scheduledAt;

  /// Raw status string from the DB (one of requested/confirmed/declined/
  /// cancelled). Mapped to the enum in [toEntity].
  final String status;

  /// Listing heading (embedded join). May be null if RLS hides the listing.
  final String? listingTitle;

  final String? note;

  /// Embedded listing fields — all null when the listing is RLS-hidden.
  final PropertyType? propertyType;
  final double? priceAmount;
  final String? priceCurrency;
  final String? publisherPhone;
  final String? publisherWhatsapp;

  factory ViewingDto.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'];
    String? title;
    PropertyType? propertyType;
    double? priceAmount;
    String? priceCurrency;
    String? phone;
    String? whatsapp;
    if (listing is Map) {
      final rawTitle = listing['title'];
      if (rawTitle is String && rawTitle.isNotEmpty) title = rawTitle;

      final rawType = listing['property_type'];
      if (rawType is String && rawType.isNotEmpty) {
        try {
          propertyType = PropertyTypeDb.fromDbValue(rawType);
        } catch (_) {
          propertyType = PropertyType.other;
        }
      }

      final rawPhone = listing['phone'];
      if (rawPhone is String && rawPhone.trim().isNotEmpty) phone = rawPhone;
      final rawWa = listing['whatsapp'];
      if (rawWa is String && rawWa.trim().isNotEmpty) whatsapp = rawWa;

      final (amount, currency) = _primaryPrice(listing['listing_prices']);
      priceAmount = amount;
      priceCurrency = currency;
    }
    return ViewingDto(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      publisherUserId: json['publisher_user_id'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      status: json['status'] as String,
      listingTitle: title,
      note: json['note'] as String?,
      propertyType: propertyType,
      priceAmount: priceAmount,
      priceCurrency: priceCurrency,
      publisherPhone: phone,
      publisherWhatsapp: whatsapp,
    );
  }

  /// Picks the primary `listing_prices` row (flagged `is_primary`, else the
  /// first), returning its (amount, currency_code). Both null when absent.
  static (double?, String?) _primaryPrice(Object? raw) {
    if (raw is! List || raw.isEmpty) return (null, null);
    Map? row;
    for (final p in raw) {
      if (p is Map && p['is_primary'] == true) {
        row = p;
        break;
      }
    }
    row ??= raw.first is Map ? raw.first as Map : null;
    if (row == null) return (null, null);
    final amount = row['amount'];
    final code = row['currency_code'];
    final parsed = amount is num
        ? amount.toDouble()
        : (amount is String ? double.tryParse(amount) : null);
    return (parsed, code is String ? code : null);
  }

  /// Maps to the domain entity. [currentUserId] decides whether the caller is
  /// the listing's publisher (the reviewer) vs the requester.
  Viewing toEntity(String currentUserId) {
    return Viewing(
      id: id,
      listingId: listingId,
      listingTitle: listingTitle,
      scheduledAt: scheduledAt,
      status: ViewingStatus.fromRaw(status),
      note: note,
      propertyType: propertyType,
      priceAmount: priceAmount,
      priceCurrency: priceCurrency,
      publisherPhone: publisherPhone,
      publisherWhatsapp: publisherWhatsapp,
      amIPublisher: currentUserId == publisherUserId,
    );
  }
}
