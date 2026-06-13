import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

class Area extends Equatable {
  const Area({
    required this.id,
    required this.cityId,
    required this.key,
    required this.displayName,
    this.description,
    this.position,
    required this.isActive,
    // Defaulted (not `required`) so existing callers that build a display-only
    // Area without centroid data (e.g. the listing-details aggregate DTO, which
    // never reads the centroid) keep compiling. The locations DTO always maps
    // the real NOT-NULL DB values; the area form reads/writes the real values.
    this.centroidLat = 0,
    this.centroidLng = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String cityId;
  final String key;
  final Map<String, String> displayName;
  final Map<String, String>? description;
  final int? position;
  final bool isActive;

  /// Area centroid latitude (DB column `centroid_lat`, NOT NULL, range 32..37).
  /// Used by the map auto-fill (FR-013a) and required when creating an area.
  final double centroidLat;

  /// Area centroid longitude (DB column `centroid_lng`, NOT NULL, range 35..43).
  final double centroidLng;

  final DateTime createdAt;
  final DateTime updatedAt;

  // R-18 fallback chain: requested locale → other locale → key
  String localizedName(Locale locale) {
    final active = displayName[locale.languageCode]?.trim();
    if (active != null && active.isNotEmpty) return active;
    final fallback = locale.languageCode == 'ar'
        ? displayName['en']
        : displayName['ar'];
    if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
    return key;
  }

  @override
  List<Object?> get props => [
    id,
    cityId,
    key,
    displayName,
    description,
    position,
    isActive,
    centroidLat,
    centroidLng,
    createdAt,
    updatedAt,
  ];
}
