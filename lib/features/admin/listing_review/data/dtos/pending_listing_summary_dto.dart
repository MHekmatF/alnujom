import 'dart:ui' show Locale;

import 'package:decimal/decimal.dart';

import '../../../../../shared/domain/value_objects/money.dart';
import '../../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/pending_listing_summary.dart';

/// Phase 12 (spec/012-listing-approval) — flat row matching the PostgREST
/// nested-select shape from `contracts/phase12-admin-queue-page.md` minus
/// the `listing_status_history` nested select (per analysis finding C8 —
/// queue uses `listings.created_at` for the cursor field).
class PendingListingSummaryDto {
  PendingListingSummaryDto({
    required this.id,
    required this.title,
    required this.purpose,
    required this.propertyType,
    required this.createdAt,
    this.publisherFullName,
    this.publisherPhone,
    this.governorateDisplayName,
    this.cityDisplayName,
    this.areaDisplayName,
    this.primaryPriceAmount,
    this.primaryPriceCurrencyCode,
    this.mainImageStoragePath,
    this.mainImagePublicUrl,
  });

  final String id;
  final String title;
  final String purpose;
  final String propertyType;
  final DateTime createdAt;

  final String? publisherFullName;
  final String? publisherPhone;

  /// JSONB `display_name` columns from `governorates` / `cities` / `areas` —
  /// a map of `{"ar": "...", "en": "..."}`. Null if the FK was null.
  final Map<String, String>? governorateDisplayName;
  final Map<String, String>? cityDisplayName;
  final Map<String, String>? areaDisplayName;

  final Decimal? primaryPriceAmount;
  final String? primaryPriceCurrencyCode;

  final String? mainImageStoragePath;

  /// Resolved public URL for [mainImageStoragePath]. The datasource computes
  /// this via `supabase.storage.from('listing-images').getPublicUrl(...)`
  /// so the presentation layer remains Constitution IX-clean.
  final String? mainImagePublicUrl;

  PendingListingSummaryDto copyWithMainImageUrl(String url) {
    return PendingListingSummaryDto(
      id: id,
      title: title,
      purpose: purpose,
      propertyType: propertyType,
      createdAt: createdAt,
      publisherFullName: publisherFullName,
      publisherPhone: publisherPhone,
      governorateDisplayName: governorateDisplayName,
      cityDisplayName: cityDisplayName,
      areaDisplayName: areaDisplayName,
      primaryPriceAmount: primaryPriceAmount,
      primaryPriceCurrencyCode: primaryPriceCurrencyCode,
      mainImageStoragePath: mainImageStoragePath,
      mainImagePublicUrl: url,
    );
  }

  /// Constructs a DTO from the PostgREST nested-select response shape.
  ///
  /// Defensive against missing nested rows: if a `governorates` row was
  /// stripped by RLS (should not happen for an admin caller but we guard),
  /// the names default to null and the entity falls back to '—'.
  static PendingListingSummaryDto fromMap(Map<String, dynamic> row) {
    final publisher = row['publisher'] as Map<String, dynamic>?;
    final governorate = row['governorate'] as Map<String, dynamic>?;
    final city = row['city'] as Map<String, dynamic>?;
    final area = row['area'] as Map<String, dynamic>?;

    // prices: array; pick the primary one. Listings with no prices yet have
    // an empty array.
    final pricesRaw = row['prices'] as List<dynamic>?;
    Map<String, dynamic>? primaryPriceRow;
    if (pricesRaw != null && pricesRaw.isNotEmpty) {
      for (final p in pricesRaw) {
        if (p is Map && p['is_primary'] == true) {
          primaryPriceRow = Map<String, dynamic>.from(p);
          break;
        }
      }
      // Fallback: if no row flagged is_primary (defensive), pick the first.
      primaryPriceRow ??= Map<String, dynamic>.from(pricesRaw.first as Map);
    }

    // media: array; pick the row flagged is_main=true. If none flagged,
    // pick the lowest-ordering row. If empty, leave null and the card
    // renders the Phase 2 placeholder.
    final mediaRaw = row['media'] as List<dynamic>?;
    String? mainImagePath;
    if (mediaRaw != null && mediaRaw.isNotEmpty) {
      Map<String, dynamic>? mainRow;
      for (final m in mediaRaw) {
        if (m is Map && m['is_main'] == true) {
          mainRow = Map<String, dynamic>.from(m);
          break;
        }
      }
      mainRow ??= Map<String, dynamic>.from(mediaRaw.first as Map);
      final raw = mainRow['storage_path'];
      if (raw is String && raw.isNotEmpty) {
        mainImagePath = raw;
      }
    }

    return PendingListingSummaryDto(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      purpose: row['purpose'] as String,
      propertyType: row['property_type'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      publisherFullName: publisher?['full_name'] as String?,
      publisherPhone: publisher?['phone'] as String?,
      governorateDisplayName: _parseLocalizedMap(governorate?['display_name']),
      cityDisplayName: _parseLocalizedMap(city?['display_name']),
      areaDisplayName: _parseLocalizedMap(area?['display_name']),
      primaryPriceAmount: _decimalOrNull(primaryPriceRow?['amount']),
      primaryPriceCurrencyCode: primaryPriceRow?['currency_code'] as String?,
      mainImageStoragePath: mainImagePath,
    );
  }

  PendingListingSummary toEntity({required Locale locale}) {
    String localized(Map<String, String>? displayName) {
      if (displayName == null || displayName.isEmpty) return '—';
      final preferred = displayName[locale.languageCode]?.trim();
      if (preferred != null && preferred.isNotEmpty) return preferred;
      final fallback = locale.languageCode == 'ar'
          ? displayName['en']?.trim()
          : displayName['ar']?.trim();
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return '—';
    }

    final publisherDisplay =
        (publisherFullName?.trim().isNotEmpty == true
            ? publisherFullName!.trim()
            : publisherPhone?.trim()) ??
        '—';

    Money? money;
    if (primaryPriceAmount != null && primaryPriceCurrencyCode != null) {
      money = Money(
        amount: primaryPriceAmount!,
        currencyCode: primaryPriceCurrencyCode!,
      );
    }

    return PendingListingSummary(
      id: id,
      title: title,
      mainImageStoragePath: mainImageStoragePath,
      mainImageUrl: mainImagePublicUrl,
      purpose: ListingPurposeDb.fromDbValue(purpose),
      propertyType: PropertyTypeDb.fromDbValue(propertyType),
      governorateName: localized(governorateDisplayName),
      cityName: localized(cityDisplayName),
      areaName: localized(areaDisplayName),
      primaryPrice: money,
      publisherDisplayName: publisherDisplay,
      submittedAt: createdAt,
    );
  }
}

Decimal? _decimalOrNull(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return Decimal.parse(raw.toString());
  if (raw is String) return Decimal.parse(raw);
  return null;
}

Map<String, String>? _parseLocalizedMap(Object? raw) {
  if (raw is! Map) return null;
  return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
}
