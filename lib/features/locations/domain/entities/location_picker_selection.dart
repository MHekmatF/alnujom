import 'package:equatable/equatable.dart';

class LocationPickerSelection extends Equatable {
  const LocationPickerSelection({
    required this.governorateId,
    required this.cityId,
    this.areaId,
  });

  final String governorateId;
  final String cityId;
  final String? areaId;

  @override
  List<Object?> get props => [governorateId, cityId, areaId];
}
