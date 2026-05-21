import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/area.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/governorate.dart';
import '../../domain/entities/location_picker_selection.dart';
import '../../domain/failures.dart';
import '../../domain/usecases/list_areas_for_city.dart';
import '../../domain/usecases/list_cities_for_governorate.dart';
import '../../domain/usecases/list_governorates.dart';

// ── Events ───────────────────────────────────────────────────────────────────

sealed class LocationPickerEvent extends Equatable {
  const LocationPickerEvent();

  @override
  List<Object?> get props => [];
}

final class LocationPickerMountRequested extends LocationPickerEvent {
  const LocationPickerMountRequested({
    this.initialGovernorateId,
    this.initialCityId,
    this.initialAreaId,
  });

  /// Optional pre-selection — used by edit-mode forms (e.g. Phase 10
  /// Resubmit on a Rejected listing) to display the previously-saved
  /// governorate/city/area in the dropdowns. The bloc chains gov → city →
  /// area loads in order.
  final String? initialGovernorateId;
  final String? initialCityId;
  final String? initialAreaId;

  @override
  List<Object?> get props => [
    initialGovernorateId,
    initialCityId,
    initialAreaId,
  ];
}

final class LocationPickerGovernoratePicked extends LocationPickerEvent {
  const LocationPickerGovernoratePicked(this.governorateId);

  final String governorateId;

  @override
  List<Object?> get props => [governorateId];
}

final class LocationPickerCityPicked extends LocationPickerEvent {
  const LocationPickerCityPicked(this.cityId);

  final String cityId;

  @override
  List<Object?> get props => [cityId];
}

final class LocationPickerAreaPicked extends LocationPickerEvent {
  const LocationPickerAreaPicked(this.areaId);

  final String? areaId;

  @override
  List<Object?> get props => [areaId];
}

final class LocationPickerReset extends LocationPickerEvent {
  const LocationPickerReset();
}

// ── States ───────────────────────────────────────────────────────────────────

sealed class LocationPickerState extends Equatable {
  const LocationPickerState();

  @override
  List<Object?> get props => [];
}

final class LocationPickerInitial extends LocationPickerState {
  const LocationPickerInitial();
}

final class LocationPickerGovernoratesLoading extends LocationPickerState {
  const LocationPickerGovernoratesLoading();
}

final class LocationPickerLoadFailed extends LocationPickerState {
  const LocationPickerLoadFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

// Single "ready" state that accumulates data as the user cascades
final class LocationPickerReady extends LocationPickerState {
  const LocationPickerReady({
    required this.governorates,
    this.selectedGovernorateId,
    this.cities = const [],
    this.citiesLoading = false,
    this.selectedCityId,
    this.areas = const [],
    this.areasLoading = false,
    this.selectedAreaId,
  });

  final List<Governorate> governorates;
  final String? selectedGovernorateId;
  final List<City> cities;
  final bool citiesLoading;
  final String? selectedCityId;
  final List<Area> areas;
  final bool areasLoading;
  final String? selectedAreaId;

  LocationPickerSelection? get currentSelection {
    if (selectedGovernorateId == null || selectedCityId == null) return null;
    return LocationPickerSelection(
      governorateId: selectedGovernorateId!,
      cityId: selectedCityId!,
      areaId: selectedAreaId,
    );
  }

  LocationPickerReady copyWith({
    List<Governorate>? governorates,
    String? Function()? selectedGovernorateId,
    List<City>? cities,
    bool? citiesLoading,
    String? Function()? selectedCityId,
    List<Area>? areas,
    bool? areasLoading,
    String? Function()? selectedAreaId,
  }) {
    return LocationPickerReady(
      governorates: governorates ?? this.governorates,
      selectedGovernorateId: selectedGovernorateId != null
          ? selectedGovernorateId()
          : this.selectedGovernorateId,
      cities: cities ?? this.cities,
      citiesLoading: citiesLoading ?? this.citiesLoading,
      selectedCityId: selectedCityId != null
          ? selectedCityId()
          : this.selectedCityId,
      areas: areas ?? this.areas,
      areasLoading: areasLoading ?? this.areasLoading,
      selectedAreaId: selectedAreaId != null
          ? selectedAreaId()
          : this.selectedAreaId,
    );
  }

  @override
  List<Object?> get props => [
    governorates,
    selectedGovernorateId,
    cities,
    citiesLoading,
    selectedCityId,
    areas,
    areasLoading,
    selectedAreaId,
  ];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

@injectable
class LocationPickerBloc
    extends Bloc<LocationPickerEvent, LocationPickerState> {
  LocationPickerBloc(
    this._listGovernorates,
    this._listCitiesForGovernorate,
    this._listAreasForCity,
  ) : super(const LocationPickerInitial()) {
    on<LocationPickerMountRequested>(_onMount);
    on<LocationPickerGovernoratePicked>(_onGovernoratePicked);
    on<LocationPickerCityPicked>(_onCityPicked);
    on<LocationPickerAreaPicked>(_onAreaPicked);
    on<LocationPickerReset>(_onReset);
  }

  final ListGovernorates _listGovernorates;
  final ListCitiesForGovernorate _listCitiesForGovernorate;
  final ListAreasForCity _listAreasForCity;

  Future<void> _onMount(
    LocationPickerMountRequested event,
    Emitter<LocationPickerState> emit,
  ) async {
    emit(const LocationPickerGovernoratesLoading());
    try {
      final govWithCounts = await _listGovernorates(includeInactive: false);
      final governorates = govWithCounts.map((g) => g.governorate).toList();

      // Fast-path: no initial selection → done.
      if (event.initialGovernorateId == null) {
        emit(LocationPickerReady(governorates: governorates));
        return;
      }

      // Edit-mode chain: load gov → cities → maybe areas. We seed state
      // synchronously rather than dispatching pick events so the
      // intermediate states don't fire onChanged callbacks that would
      // overwrite the consumer's pre-loaded BLoC state.
      final cities = (await _listCitiesForGovernorate(
        governorateId: event.initialGovernorateId!,
        includeInactive: false,
      )).map((c) => c.city).toList();

      List<Area> areas = const [];
      if (event.initialCityId != null) {
        areas = await _listAreasForCity(
          cityId: event.initialCityId!,
          includeInactive: false,
        );
      }

      emit(
        LocationPickerReady(
          governorates: governorates,
          cities: cities,
          areas: areas,
          selectedGovernorateId: event.initialGovernorateId,
          selectedCityId: event.initialCityId,
          selectedAreaId: event.initialAreaId,
        ),
      );
    } on LocationsFailure catch (failure) {
      emit(LocationPickerLoadFailed(failure.message));
    } on Object catch (error) {
      emit(LocationPickerLoadFailed(error.toString()));
    }
  }

  Future<void> _onGovernoratePicked(
    LocationPickerGovernoratePicked event,
    Emitter<LocationPickerState> emit,
  ) async {
    final ready = state;
    if (ready is! LocationPickerReady) return;

    emit(
      ready.copyWith(
        selectedGovernorateId: () => event.governorateId,
        cities: const [],
        citiesLoading: true,
        selectedCityId: () => null,
        areas: const [],
        selectedAreaId: () => null,
      ),
    );

    try {
      final citiesWithCount = await _listCitiesForGovernorate(
        governorateId: event.governorateId,
        includeInactive: false,
      );
      final cities = citiesWithCount.map((c) => c.city).toList();
      final current = state;
      if (current is LocationPickerReady &&
          current.selectedGovernorateId == event.governorateId) {
        emit(current.copyWith(cities: cities, citiesLoading: false));
      }
    } on LocationsFailure catch (failure) {
      emit(LocationPickerLoadFailed(failure.message));
    } on Object catch (error) {
      emit(LocationPickerLoadFailed(error.toString()));
    }
  }

  Future<void> _onCityPicked(
    LocationPickerCityPicked event,
    Emitter<LocationPickerState> emit,
  ) async {
    final ready = state;
    if (ready is! LocationPickerReady) return;

    emit(
      ready.copyWith(
        selectedCityId: () => event.cityId,
        areas: const [],
        areasLoading: true,
        selectedAreaId: () => null,
      ),
    );

    try {
      final areas = await _listAreasForCity(
        cityId: event.cityId,
        includeInactive: false,
      );
      final current = state;
      if (current is LocationPickerReady &&
          current.selectedCityId == event.cityId) {
        emit(current.copyWith(areas: areas, areasLoading: false));
      }
    } on LocationsFailure catch (failure) {
      emit(LocationPickerLoadFailed(failure.message));
    } on Object catch (error) {
      emit(LocationPickerLoadFailed(error.toString()));
    }
  }

  void _onAreaPicked(
    LocationPickerAreaPicked event,
    Emitter<LocationPickerState> emit,
  ) {
    final ready = state;
    if (ready is! LocationPickerReady) return;
    emit(ready.copyWith(selectedAreaId: () => event.areaId));
  }

  void _onReset(LocationPickerReset event, Emitter<LocationPickerState> emit) {
    final ready = state;
    if (ready is! LocationPickerReady) return;
    emit(LocationPickerReady(governorates: ready.governorates));
  }
}
