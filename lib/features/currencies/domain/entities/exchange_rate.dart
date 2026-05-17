import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

class ExchangeRate extends Equatable {
  final String id;
  final String baseCurrency;
  final String targetCurrency;
  final Decimal rate;
  final DateTime effectiveAt;
  final String? setBy;
  final String? setByDisplayName;
  final String? source;
  final DateTime createdAt;

  const ExchangeRate({
    required this.id,
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.effectiveAt,
    required this.setBy,
    this.setByDisplayName,
    required this.source,
    required this.createdAt,
  });

  bool get isDerived => source?.startsWith('auto-derived from ') ?? false;

  @override
  List<Object?> get props => [
    id,
    baseCurrency,
    targetCurrency,
    rate,
    effectiveAt,
    setBy,
    setByDisplayName,
    source,
    createdAt,
  ];
}
