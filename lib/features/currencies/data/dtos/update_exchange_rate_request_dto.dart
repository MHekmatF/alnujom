import 'package:decimal/decimal.dart';

class UpdateExchangeRateRequestDto {
  const UpdateExchangeRateRequestDto({
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.effectiveAt,
    required this.sourceText,
  });

  final String baseCurrency;
  final String targetCurrency;
  final Decimal rate;
  final DateTime effectiveAt;
  final String? sourceText;

  Map<String, dynamic> toRpcParams() => {
    'p_base_currency': baseCurrency,
    'p_target_currency': targetCurrency,
    'p_rate': rate.toString(),
    'p_effective_at': effectiveAt.toUtc().toIso8601String(),
    if (sourceText != null) 'p_source': sourceText,
  };
}
