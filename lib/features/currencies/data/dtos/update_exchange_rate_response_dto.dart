import '../../domain/entities/update_exchange_rate_result.dart';
import 'exchange_rate_dto.dart';

class UpdateExchangeRateResponseDto {
  const UpdateExchangeRateResponseDto({
    required this.adminRow,
    required this.derivedRow,
  });

  factory UpdateExchangeRateResponseDto.fromJson(Map<String, dynamic> json) {
    return UpdateExchangeRateResponseDto(
      adminRow: ExchangeRateDto.fromJson(
        Map<String, dynamic>.from(json['admin_row'] as Map),
      ),
      derivedRow: ExchangeRateDto.fromJson(
        Map<String, dynamic>.from(json['derived_row'] as Map),
      ),
    );
  }

  final ExchangeRateDto adminRow;
  final ExchangeRateDto derivedRow;

  UpdateExchangeRateResult toDomain() {
    return UpdateExchangeRateResult(
      adminRow: adminRow.toDomain(),
      derivedRow: derivedRow.toDomain(),
    );
  }
}
