class CurrencyMutationRequestDto {
  const CurrencyMutationRequestDto({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.symbol,
    required this.sortOrder,
    required this.displayDecimals,
    required this.isActive,
  });

  final String code;
  final String nameAr;
  final String nameEn;
  final String symbol;
  final int sortOrder;
  final int displayDecimals;
  final bool isActive;

  Map<String, dynamic> toRow() => {
    'code': code,
    'name_ar': nameAr,
    'name_en': nameEn,
    'symbol': symbol,
    'sort_order': sortOrder,
    'display_decimals': displayDecimals,
    'is_active': isActive,
  };
}
