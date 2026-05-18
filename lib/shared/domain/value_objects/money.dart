import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

class Money extends Equatable {
  final Decimal amount;
  final String currencyCode;

  const Money({required this.amount, required this.currencyCode});

  @override
  List<Object?> get props => [amount, currencyCode];
}
