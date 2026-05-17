import 'package:decimal/decimal.dart';

import '../../domain/entities/exchange_rate.dart';

class ExchangeRateDto {
  const ExchangeRateDto({
    required this.id,
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.effectiveAt,
    required this.setBy,
    required this.setByDisplayName,
    required this.source,
    required this.createdAt,
  });

  factory ExchangeRateDto.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    final profileMap = profile is Map<String, dynamic> ? profile : null;
    return ExchangeRateDto(
      id: json['id'] as String,
      baseCurrency: json['base_currency'] as String,
      targetCurrency: json['target_currency'] as String,
      rate: Decimal.parse(
        json['rate'] is String
            ? json['rate'] as String
            : json['rate'].toString(),
      ),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      setBy: json['set_by'] as String?,
      setByDisplayName:
          profileMap?['display_name'] as String? ??
          profileMap?['username'] as String?,
      source: json['source'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String baseCurrency;
  final String targetCurrency;
  final Decimal rate;
  final DateTime effectiveAt;
  final String? setBy;
  final String? setByDisplayName;
  final String? source;
  final DateTime createdAt;

  ExchangeRate toDomain() {
    return ExchangeRate(
      id: id,
      baseCurrency: baseCurrency,
      targetCurrency: targetCurrency,
      rate: rate,
      effectiveAt: effectiveAt,
      setBy: setBy,
      setByDisplayName: setByDisplayName,
      source: source,
      createdAt: createdAt,
    );
  }
}
