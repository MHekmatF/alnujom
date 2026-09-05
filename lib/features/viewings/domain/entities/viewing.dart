// lib/features/viewings/domain/entities/viewing.dart
//
// Viewing scheduler — domain entity for one scheduled property viewing.

import '../../../listing_form/domain/entities/listing.dart' show PropertyType;

/// Plan A36 — rows per page of the viewings list (keyset on `scheduled_at`).
const int kViewingsPageSize = 30;

/// The lifecycle status of a viewing request.
///
/// A requester opens a viewing as [requested]; the publisher then
/// [confirmed]/[declined]; either party may [cancelled] (per the RPC contract).
enum ViewingStatus {
  requested,
  confirmed,
  declined,
  cancelled;

  /// Parses the raw DB string into the enum. Unknown values fall back to
  /// [requested] (defensive — the DB CHECK constrains it to these four).
  static ViewingStatus fromRaw(String raw) {
    return switch (raw) {
      'confirmed' => ViewingStatus.confirmed,
      'declined' => ViewingStatus.declined,
      'cancelled' => ViewingStatus.cancelled,
      _ => ViewingStatus.requested,
    };
  }

  /// The wire value sent back to the RPC.
  String get wire => name;
}

/// Immutable domain representation of a `public.viewings` row, augmented with
/// the listing heading the UI renders + the caller's role on this row.
class Viewing {
  const Viewing({
    required this.id,
    required this.listingId,
    required this.scheduledAt,
    required this.status,
    required this.amIPublisher,
    this.listingTitle,
    this.note,
    this.propertyType,
    this.priceAmount,
    this.priceCurrency,
    this.publisherPhone,
    this.publisherWhatsapp,
  });

  /// UUID primary key.
  final String id;

  final String listingId;

  /// Listing title used as the row heading. May be null when RLS hides the
  /// listing (deleted/unapproved) — the UI falls back to a generic label.
  final String? listingTitle;

  /// The proposed viewing time (UTC from the DB; rendered in local time).
  final DateTime scheduledAt;

  final ViewingStatus status;

  final String? note;

  /// Listing property type — drives the card's placeholder icon. Null when RLS
  /// hides the listing.
  final PropertyType? propertyType;

  /// Primary-price amount + currency code (embedded from `listing_prices`), used
  /// to render the price line on the requester's «معايناتي» card. Both null when
  /// the listing (and hence its price) is not readable.
  final double? priceAmount;
  final String? priceCurrency;

  /// The listing's public contact number / WhatsApp number — how the *requester*
  /// reaches the publisher from a viewing card. Null when unset or RLS-hidden.
  final String? publisherPhone;
  final String? publisherWhatsapp;

  /// `true` when the caller is the listing's publisher (the party who may
  /// confirm/decline); `false` when the caller is the requester.
  final bool amIPublisher;

  @override
  String toString() => 'Viewing(id: $id, status: ${status.name})';
}
