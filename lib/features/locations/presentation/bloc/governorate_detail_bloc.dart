import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/city_with_area_count.dart';
import '../../domain/entities/governorate.dart';
import '../../domain/failures.dart';
import '../../domain/usecases/list_cities_for_governorate.dart';
import '../../domain/usecases/load_governorate_detail.dart';

sealed class GovernorateDetailEvent extends Equatable {
  const GovernorateDetailEvent();

  @override
  List<Object?> get props => [];
}

final class GovernorateDetailLoadRequested extends GovernorateDetailEvent {
  const GovernorateDetailLoadRequested(this.governorateId);

  final String governorateId;

  @override
  List<Object?> get props => [governorateId];
}

final class GovernorateDetailRefreshRequested extends GovernorateDetailEvent {
  const GovernorateDetailRefreshRequested();
}

sealed class GovernorateDetailState extends Equatable {
  const GovernorateDetailState();

  @override
  List<Object?> get props => [];
}

final class GovernorateDetailLoading extends GovernorateDetailState {
  const GovernorateDetailLoading();
}

final class GovernorateDetailLoaded extends GovernorateDetailState {
  const GovernorateDetailLoaded({
    required this.governorate,
    required this.cities,
  });

  final Governorate governorate;
  final List<CityWithAreaCount> cities;

  @override
  List<Object?> get props => [governorate, cities];
}

final class GovernorateDetailError extends GovernorateDetailState {
  const GovernorateDetailError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

@injectable
class GovernorateDetailBloc
    extends Bloc<GovernorateDetailEvent, GovernorateDetailState> {
  GovernorateDetailBloc(
    this._loadGovernorateDetail,
    this._listCitiesForGovernorate,
  ) : super(const GovernorateDetailLoading()) {
    on<GovernorateDetailLoadRequested>(_load);
    on<GovernorateDetailRefreshRequested>(_refresh);
  }

  final LoadGovernorateDetail _loadGovernorateDetail;
  final ListCitiesForGovernorate _listCitiesForGovernorate;

  String? _currentGovernorateId;

  Future<void> _load(
    GovernorateDetailLoadRequested event,
    Emitter<GovernorateDetailState> emit,
  ) async {
    _currentGovernorateId = event.governorateId;
    emit(const GovernorateDetailLoading());
    await _fetch(event.governorateId, emit);
  }

  Future<void> _refresh(
    GovernorateDetailRefreshRequested event,
    Emitter<GovernorateDetailState> emit,
  ) async {
    final id = _currentGovernorateId;
    if (id == null) return;
    await _fetch(id, emit);
  }

  Future<void> _fetch(
    String governorateId,
    Emitter<GovernorateDetailState> emit,
  ) async {
    try {
      final results = await Future.wait([
        _loadGovernorateDetail(governorateId),
        _listCitiesForGovernorate(
          governorateId: governorateId,
          includeInactive: true,
        ),
      ]);
      final governorate = results[0] as Governorate;
      final cities = results[1] as List<CityWithAreaCount>;
      emit(GovernorateDetailLoaded(governorate: governorate, cities: cities));
    } on LocationsFailure catch (failure) {
      emit(GovernorateDetailError(failure.message));
    } on Object catch (error) {
      emit(GovernorateDetailError(error.toString()));
    }
  }
}
