import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

class ListingPrice extends Equatable {
  const ListingPrice({
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

  ListingPrice copyWith({
    String? id,
    String? listingId,
    String? currencyCode,
    Decimal? amount,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return ListingPrice(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      currencyCode: currencyCode ?? this.currencyCode,
      amount: amount ?? this.amount,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    listingId,
    currencyCode,
    amount,
    isPrimary,
    createdAt,
  ];
}
