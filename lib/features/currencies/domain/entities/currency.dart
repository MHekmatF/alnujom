import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show Locale;

class Currency extends Equatable {
  final String code;
  final String nameAr;
  final String nameEn;
  final String symbol;
  final bool isActive;
  final int sortOrder;
  final bool isSystem;
  final int displayDecimals;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Currency({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.symbol,
    required this.isActive,
    required this.sortOrder,
    required this.isSystem,
    required this.displayDecimals,
    required this.createdAt,
    required this.updatedAt,
  });

  String localizedName(Locale locale) {
    final value = locale.languageCode == 'ar' ? nameAr.trim() : nameEn.trim();
    if (value.isNotEmpty) return value;
    final fallback = locale.languageCode == 'ar'
        ? nameEn.trim()
        : nameAr.trim();
    return fallback.isNotEmpty ? fallback : code;
  }

  @override
  List<Object?> get props => [
    code,
    nameAr,
    nameEn,
    symbol,
    isActive,
    sortOrder,
    isSystem,
    displayDecimals,
    createdAt,
    updatedAt,
  ];
}
