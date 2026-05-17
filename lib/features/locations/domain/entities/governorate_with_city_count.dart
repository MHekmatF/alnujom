import 'package:equatable/equatable.dart';

import 'governorate.dart';

class GovernorateWithCityCount extends Equatable {
  const GovernorateWithCityCount({
    required this.governorate,
    required this.cityCount,
  });

  final Governorate governorate;
  final int cityCount;

  @override
  List<Object?> get props => [governorate, cityCount];
}
