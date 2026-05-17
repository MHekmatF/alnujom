import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/area.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/governorate.dart';
import '../../domain/failures.dart';
import '../../domain/usecases/list_areas_for_city.dart';
import '../../domain/usecases/load_city_detail.dart';
import '../../domain/usecases/load_governorate_detail.dart';

sealed class CityDetailEvent extends Equatable {
  const CityDetailEvent();

  @override
  List<Object?> get props => [];
}

final class CityDetailLoadRequested extends CityDetailEvent {
  const CityDetailLoadRequested(this.cityId);

  final String cityId;

  @override
  List<Object?> get props => [cityId];
}

final class CityDetailRefreshRequested extends CityDetailEvent {
  const CityDetailRefreshRequested();
}

sealed class CityDetailState extends Equatable {
  const CityDetailState();

  @override
  List<Object?> get props => [];
}

final class CityDetailLoading extends CityDetailState {
  const CityDetailLoading();
}

final class CityDetailLoaded extends CityDetailState {
  const CityDetailLoaded({
    required this.city,
    required this.governorate,
    required this.areas,
  });

  final City city;
  final Governorate governorate;
  final List<Area> areas;

  @override
  List<Object?> get props => [city, governorate, areas];
}

final class CityDetailError extends CityDetailState {
  const CityDetailError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

@injectable
class CityDetailBloc extends Bloc<CityDetailEvent, CityDetailState> {
  CityDetailBloc(
    this._loadCityDetail,
    this._loadGovernorateDetail,
    this._listAreasForCity,
  ) : super(const CityDetailLoading()) {
    on<CityDetailLoadRequested>(_load);
    on<CityDetailRefreshRequested>(_refresh);
  }

  final LoadCityDetail _loadCityDetail;
  final LoadGovernorateDetail _loadGovernorateDetail;
  final ListAreasForCity _listAreasForCity;

  String? _currentCityId;

  Future<void> _load(
    CityDetailLoadRequested event,
    Emitter<CityDetailState> emit,
  ) async {
    _currentCityId = event.cityId;
    emit(const CityDetailLoading());
    await _fetch(event.cityId, emit);
  }

  Future<void> _refresh(
    CityDetailRefreshRequested event,
    Emitter<CityDetailState> emit,
  ) async {
    final id = _currentCityId;
    if (id == null) return;
    await _fetch(id, emit);
  }

  Future<void> _fetch(String cityId, Emitter<CityDetailState> emit) async {
    try {
      final city = await _loadCityDetail(cityId);
      final results = await Future.wait([
        _loadGovernorateDetail(city.governorateId),
        _listAreasForCity(cityId: cityId, includeInactive: true),
      ]);
      final governorate = results[0] as Governorate;
      final areas = results[1] as List<Area>;
      emit(CityDetailLoaded(city: city, governorate: governorate, areas: areas));
    } on LocationsFailure catch (failure) {
      emit(CityDetailError(failure.message));
    } on Object catch (error) {
      emit(CityDetailError(error.toString()));
    }
  }
}
