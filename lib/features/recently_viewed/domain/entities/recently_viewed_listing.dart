import 'package:equatable/equatable.dart';

/// A lightweight, locally-persisted summary of a listing the user has opened.
///
/// Intentionally tiny — it carries ONLY what the Home "recently viewed" row
/// needs to render a compact card and route on tap (id + a thumbnail/price/
/// location summary). It is NOT a read-model of the live listing: the data is a
/// snapshot captured at view-time and may be stale (price changed, listing
/// removed). Tapping always re-fetches the live aggregate via the details page.
///
/// Serialized to a JSON map (see [toJson]/[fromJson]) for storage in
/// flutter_secure_storage by [RecentlyViewedStore].
class RecentlyViewedListing extends Equatable {
  const RecentlyViewedListing({
    required this.id,
    required this.title,
    this.mainImageUrl,
    this.priceAmount,
    this.currencyCode,
    this.governorateName,
  });

  /// Listing UUID — the de-dup key and the navigation target.
  final String id;

  /// Listing title snapshot at view-time.
  final String title;

  /// Resolved public URL of the listing's main image (already URL-rendered by
  /// the data layer); null when the listing had no main image.
  final String? mainImageUrl;

  /// Primary price amount, persisted as a plain string (decimal-safe; mirrors
  /// the favorites card which only carries the primary amount, not the full
  /// currency catalog). Null when the listing had no price.
  final String? priceAmount;

  /// ISO currency code for [priceAmount]; null when there is no price.
  final String? currencyCode;

  /// Localized governorate name snapshot (already resolved for the view-time
  /// locale); null/empty when unknown.
  final String? governorateName;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    if (mainImageUrl != null) 'mainImageUrl': mainImageUrl,
    if (priceAmount != null) 'priceAmount': priceAmount,
    if (currencyCode != null) 'currencyCode': currencyCode,
    if (governorateName != null) 'governorateName': governorateName,
  };

  /// Rebuilds an item from a stored JSON map, returning null when the map is
  /// malformed or missing the required id (so a corrupt entry is skipped rather
  /// than crashing the whole list).
  static RecentlyViewedListing? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final title = raw['title'];
    return RecentlyViewedListing(
      id: id,
      title: title is String ? title : '',
      mainImageUrl: raw['mainImageUrl'] is String
          ? raw['mainImageUrl'] as String
          : null,
      priceAmount: raw['priceAmount'] is String
          ? raw['priceAmount'] as String
          : null,
      currencyCode: raw['currencyCode'] is String
          ? raw['currencyCode'] as String
          : null,
      governorateName: raw['governorateName'] is String
          ? raw['governorateName'] as String
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    mainImageUrl,
    priceAmount,
    currencyCode,
    governorateName,
  ];
}
