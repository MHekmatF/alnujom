import 'dart:ui' show Locale;

import '../../domain/entities/reel.dart';
import '../reels_storage_url_resolver.dart';

/// Phase 029 (Reels W4) — flat DTO for one `list_video_reels` RPC row.
///
/// The RPC returns bilingual location names as separate `*_name_ar` /
/// `*_name_en` columns (mirroring `v_listings_public`), the primary price as
/// `primary_amount` / `primary_currency`, and bare storage paths for the video
/// and poster. Locale resolution + storage-URL resolution happen at
/// [toEntity]-time so the entity is presentation-ready.
class ReelDto {
  const ReelDto({
    required this.listingId,
    required this.title,
    required this.propertyType,
    required this.purpose,
    required this.publishedAt,
    required this.videoPath,
    this.posterImagePath,
    this.governorateNameAr,
    this.governorateNameEn,
    this.cityNameAr,
    this.cityNameEn,
    this.primaryAmount,
    this.primaryCurrency,
  });

  final String listingId;
  final String title;
  final String propertyType;
  final String purpose;
  final DateTime publishedAt;
  final String videoPath;
  final String? posterImagePath;
  final String? governorateNameAr;
  final String? governorateNameEn;
  final String? cityNameAr;
  final String? cityNameEn;
  final String? primaryAmount;
  final String? primaryCurrency;

  static ReelDto fromJson(Map<String, dynamic> row) {
    return ReelDto(
      listingId: row['listing_id'] as String,
      title: (row['title'] as String?) ?? '',
      propertyType: row['property_type'] as String,
      purpose: row['purpose'] as String,
      publishedAt: DateTime.parse(row['published_at'] as String),
      videoPath: row['video_path'] as String,
      posterImagePath: _str(row['poster_image_path']),
      governorateNameAr: _str(row['governorate_name_ar']),
      governorateNameEn: _str(row['governorate_name_en']),
      cityNameAr: _str(row['city_name_ar']),
      cityNameEn: _str(row['city_name_en']),
      // NUMERIC arrives as String or num over the wire; keep it as a plain
      // string (the UI formats it with the active locale's numerals).
      primaryAmount: _str(row['primary_amount']),
      primaryCurrency: _str(row['primary_currency']),
    );
  }

  Reel toEntity({required Locale locale}) {
    return Reel(
      listingId: listingId,
      title: title,
      propertyType: propertyType,
      purpose: purpose,
      locationLabel: _locationLabel(locale),
      publishedAt: publishedAt,
      videoUrl: ReelsStorageUrlResolver.video(videoPath) ?? '',
      posterImageUrl: ReelsStorageUrlResolver.poster(posterImagePath),
      priceAmount: primaryAmount,
      priceCurrency: primaryCurrency,
    );
  }

  /// "City، Governorate" for the active locale, falling back per-name to the
  /// other locale, then collapsing to whatever is present; em-dash when empty.
  String _locationLabel(Locale locale) {
    final city = _localized(
      locale,
      ar: cityNameAr,
      en: cityNameEn,
    );
    final gov = _localized(
      locale,
      ar: governorateNameAr,
      en: governorateNameEn,
    );
    final parts = [city, gov].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '—';
    // Comma joiner is direction-neutral; the surrounding Text resolves RTL.
    return parts.join('، ');
  }

  static String _localized(Locale locale, {String? ar, String? en}) {
    final preferred = (locale.languageCode == 'ar' ? ar : en)?.trim();
    if (preferred != null && preferred.isNotEmpty) return preferred;
    final fallback = (locale.languageCode == 'ar' ? en : ar)?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return '';
  }

  static String? _str(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString();
    return s.isEmpty ? null : s;
  }
}
