import 'package:equatable/equatable.dart';

import 'exchange_rate.dart';

class UpdateExchangeRateResult extends Equatable {
  final ExchangeRate adminRow;
  final ExchangeRate derivedRow;

  const UpdateExchangeRateResult({
    required this.adminRow,
    required this.derivedRow,
  });

  @override
  List<Object?> get props => [adminRow, derivedRow];
}
