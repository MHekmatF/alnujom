import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

class Governorate extends Equatable {
  const Governorate({
    required this.id,
    required this.key,
    required this.displayName,
    this.description,
    this.position,
    required this.isActive,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String key;
  final Map<String, String> displayName;
  final Map<String, String>? description;
  final int? position;
  final bool isActive;
  final bool isSystem;
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
    key,
    displayName,
    description,
    position,
    isActive,
    isSystem,
    createdAt,
    updatedAt,
  ];
}
