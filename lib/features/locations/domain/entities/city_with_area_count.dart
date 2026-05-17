import 'package:equatable/equatable.dart';

import 'city.dart';

class CityWithAreaCount extends Equatable {
  const CityWithAreaCount({required this.city, required this.areaCount});

  final City city;
  final int areaCount;

  @override
  List<Object?> get props => [city, areaCount];
}
