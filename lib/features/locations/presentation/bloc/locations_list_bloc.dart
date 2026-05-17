import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/governorate_with_city_count.dart';
import '../../domain/failures.dart';
import '../../domain/usecases/list_governorates.dart';

sealed class LocationsListEvent extends Equatable {
  const LocationsListEvent();

  @override
  List<Object?> get props => [];
}

final class LoadRequested extends LocationsListEvent {
  const LoadRequested();
}

final class RefreshRequested extends LocationsListEvent {
  const RefreshRequested();
}

sealed class LocationsListState extends Equatable {
  const LocationsListState();

  @override
  List<Object?> get props => [];
}

final class LocationsListLoading extends LocationsListState {
  const LocationsListLoading();
}

final class LocationsListLoaded extends LocationsListState {
  const LocationsListLoaded(this.governorates);

  final List<GovernorateWithCityCount> governorates;

  @override
  List<Object?> get props => [governorates];
}

final class LocationsListError extends LocationsListState {
  const LocationsListError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

@injectable
class LocationsListBloc extends Bloc<LocationsListEvent, LocationsListState> {
  LocationsListBloc(this._listGovernorates)
    : super(const LocationsListLoading()) {
    on<LoadRequested>(_load);
    on<RefreshRequested>(_load);
  }

  final ListGovernorates _listGovernorates;

  Future<void> _load(
    LocationsListEvent event,
    Emitter<LocationsListState> emit,
  ) async {
    emit(const LocationsListLoading());
    try {
      final governorates = await _listGovernorates(includeInactive: true);
      emit(LocationsListLoaded(governorates));
    } on LocationsFailure catch (failure) {
      emit(LocationsListError(failure.message));
    } on Object catch (error) {
      emit(LocationsListError(error.toString()));
    }
  }
}
