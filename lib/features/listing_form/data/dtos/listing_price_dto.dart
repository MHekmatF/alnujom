import 'package:decimal/decimal.dart';

import '../../domain/entities/listing_price.dart';

class ListingPriceDto {
  const ListingPriceDto({
    required this.id,
    required this.listingId,
    required this.currencyCode,
    required this.amount,
    required this.isPrimary,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String currencyCode;
  final Decimal amount;
  final bool isPrimary;
  final DateTime createdAt;

  static ListingPriceDto fromMap(Map<String, dynamic> row) {
    final amountRaw = row['amount'];
    final amount = amountRaw is num
        ? Decimal.parse(amountRaw.toString())
        : Decimal.parse(amountRaw as String);
    return ListingPriceDto(
      id: row['id'] as String,
      listingId: row['listing_id'] as String,
      currencyCode: row['currency_code'] as String,
      amount: amount,
      isPrimary: row['is_primary'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  ListingPrice toEntity() {
    return ListingPrice(
      id: id,
      listingId: listingId,
      currencyCode: currencyCode,
      amount: amount,
      isPrimary: isPrimary,
      createdAt: createdAt,
    );
  }
}
