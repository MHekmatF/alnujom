import '../../domain/entities/currency.dart';

class CurrencyDto {
  const CurrencyDto({
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

  factory CurrencyDto.fromJson(Map<String, dynamic> json) {
    return CurrencyDto(
      code: json['code'] as String,
      nameAr: json['name_ar'] as String,
      nameEn: json['name_en'] as String,
      symbol: json['symbol'] as String,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 100,
      isSystem: json['is_system'] as bool? ?? false,
      displayDecimals: json['display_decimals'] as int? ?? 2,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

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

  Currency toDomain() {
    return Currency(
      code: code,
      nameAr: nameAr,
      nameEn: nameEn,
      symbol: symbol,
      isActive: isActive,
      sortOrder: sortOrder,
      isSystem: isSystem,
      displayDecimals: displayDecimals,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
