import '../../domain/entities/governorate_with_city_count.dart';
import 'dto_helpers.dart';
import 'governorate_dto.dart';

class GovernorateWithCityCountDto {
  const GovernorateWithCityCountDto({
    required this.governorate,
    required this.cityCount,
  });

  factory GovernorateWithCityCountDto.fromJson(Map<String, dynamic> json) {
    return GovernorateWithCityCountDto(
      governorate: GovernorateDto.fromJson(json),
      cityCount: parseNestedCount(json['cities']),
    );
  }

  final GovernorateDto governorate;
  final int cityCount;

  GovernorateWithCityCount toEntity() {
    return GovernorateWithCityCount(
      governorate: governorate.toEntity(),
      cityCount: cityCount,
    );
  }
}
