import '../../domain/entities/city_with_area_count.dart';
import 'city_dto.dart';
import 'dto_helpers.dart';

class CityWithAreaCountDto {
  const CityWithAreaCountDto({required this.city, required this.areaCount});

  factory CityWithAreaCountDto.fromJson(Map<String, dynamic> json) {
    return CityWithAreaCountDto(
      city: CityDto.fromJson(json),
      areaCount: parseNestedCount(json['areas']),
    );
  }

  final CityDto city;
  final int areaCount;

  CityWithAreaCount toEntity() {
    return CityWithAreaCount(city: city.toEntity(), areaCount: areaCount);
  }
}
