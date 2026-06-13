import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/failures.dart';
import '../../domain/usecases/create_area.dart';
import '../../domain/usecases/create_city.dart';
import '../../domain/usecases/create_governorate.dart';
import '../../domain/usecases/load_area_detail.dart';
import '../../domain/usecases/load_city_detail.dart';
import '../../domain/usecases/load_governorate_detail.dart';
import '../../domain/usecases/update_area.dart';
import '../../domain/usecases/update_city.dart';
import '../../domain/usecases/update_governorate.dart';

enum LocationFormMode { add, edit }

enum LocationLevel { governorate, city, area }

// ── Events ───────────────────────────────────────────────────────────────────

sealed class LocationFormEvent extends Equatable {
  const LocationFormEvent();

  @override
  List<Object?> get props => [];
}

final class FormOpened extends LocationFormEvent {
  const FormOpened({
    required this.mode,
    required this.level,
    this.id,
    this.parentId,
  });

  final LocationFormMode mode;
  final LocationLevel level;
  final String? id;
  final String? parentId;

  @override
  List<Object?> get props => [mode, level, id, parentId];
}

final class KeyChanged extends LocationFormEvent {
  const KeyChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

final class ArabicNameChanged extends LocationFormEvent {
  const ArabicNameChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

final class EnglishNameChanged extends LocationFormEvent {
  const EnglishNameChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

final class PositionChanged extends LocationFormEvent {
  const PositionChanged(this.value);

  final int? value;

  @override
  List<Object?> get props => [value];
}

final class IsActiveToggled extends LocationFormEvent {
  const IsActiveToggled({required this.value});

  final bool value;

  @override
  List<Object?> get props => [value];
}

/// Area-only: the centroid coordinate (from the map picker or the manual
/// lat/lng inputs). Governorate/city levels have no centroid columns and
/// never dispatch this.
final class CentroidChanged extends LocationFormEvent {
  const CentroidChanged({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  List<Object?> get props => [lat, lng];
}

final class SaveRequested extends LocationFormEvent {
  const SaveRequested();
}

// ── States ───────────────────────────────────────────────────────────────────

sealed class LocationFormState extends Equatable {
  const LocationFormState();

  @override
  List<Object?> get props => [];
}

final class LocationFormIdle extends LocationFormState {
  const LocationFormIdle();
}

final class LocationFormLoading extends LocationFormState {
  const LocationFormLoading();
}

final class LocationFormEditing extends LocationFormState {
  const LocationFormEditing({
    required this.mode,
    required this.level,
    this.id,
    this.parentId,
    required this.key,
    required this.arabicName,
    this.englishName,
    this.position,
    required this.isActive,
    this.centroidLat,
    this.centroidLng,
    this.isLoadedSystemRow = false,
    this.isSaving = false,
  });

  final LocationFormMode mode;
  final LocationLevel level;
  final String? id;
  final String? parentId;
  final String key;
  final String arabicName;
  final String? englishName;
  final int? position;
  final bool isActive;

  /// Area-only centroid (null until the picker/inputs supply one). Governorate
  /// and city forms leave these null and never read them.
  final double? centroidLat;
  final double? centroidLng;

  final bool isLoadedSystemRow;
  final bool isSaving;

  LocationFormEditing copyWith({
    String? key,
    String? arabicName,
    String? englishName,
    int? Function()? position,
    bool? isActive,
    double? centroidLat,
    double? centroidLng,
    bool? isSaving,
  }) {
    return LocationFormEditing(
      mode: mode,
      level: level,
      id: id,
      parentId: parentId,
      key: key ?? this.key,
      arabicName: arabicName ?? this.arabicName,
      englishName: englishName ?? this.englishName,
      position: position != null ? position() : this.position,
      isActive: isActive ?? this.isActive,
      centroidLat: centroidLat ?? this.centroidLat,
      centroidLng: centroidLng ?? this.centroidLng,
      isLoadedSystemRow: isLoadedSystemRow,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    level,
    id,
    parentId,
    key,
    arabicName,
    englishName,
    position,
    isActive,
    centroidLat,
    centroidLng,
    isLoadedSystemRow,
    isSaving,
  ];
}

final class LocationFormSaveSuccess extends LocationFormState {
  const LocationFormSaveSuccess();
}

final class LocationFormSaveFailure extends LocationFormState {
  const LocationFormSaveFailure(this.failure);

  final LocationsFailure failure;

  @override
  List<Object?> get props => [failure];
}

final class LocationFormLoadFailed extends LocationFormState {
  const LocationFormLoadFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

@injectable
class LocationFormBloc extends Bloc<LocationFormEvent, LocationFormState> {
  LocationFormBloc(
    this._loadGovernorateDetail,
    this._loadCityDetail,
    this._loadAreaDetail,
    this._createGovernorate,
    this._updateGovernorate,
    this._createCity,
    this._updateCity,
    this._createArea,
    this._updateArea,
  ) : super(const LocationFormIdle()) {
    on<FormOpened>(_onFormOpened);
    on<KeyChanged>(_onKeyChanged);
    on<ArabicNameChanged>(_onArabicNameChanged);
    on<EnglishNameChanged>(_onEnglishNameChanged);
    on<PositionChanged>(_onPositionChanged);
    on<IsActiveToggled>(_onIsActiveToggled);
    on<CentroidChanged>(_onCentroidChanged);
    on<SaveRequested>(_onSaveRequested);
  }

  // Mirror the DB CHECK constraint on `areas` (centroid_lat 32..37,
  // centroid_lng 35..43) so the user gets a friendly error before the insert.
  static const double centroidLatMin = 32;
  static const double centroidLatMax = 37;
  static const double centroidLngMin = 35;
  static const double centroidLngMax = 43;

  final LoadGovernorateDetail _loadGovernorateDetail;
  final LoadCityDetail _loadCityDetail;
  final LoadAreaDetail _loadAreaDetail;
  final CreateGovernorate _createGovernorate;
  final UpdateGovernorate _updateGovernorate;
  final CreateCity _createCity;
  final UpdateCity _updateCity;
  final CreateArea _createArea;
  final UpdateArea _updateArea;

  Future<void> _onFormOpened(
    FormOpened event,
    Emitter<LocationFormState> emit,
  ) async {
    if (event.mode == LocationFormMode.add) {
      emit(
        LocationFormEditing(
          mode: event.mode,
          level: event.level,
          parentId: event.parentId,
          key: '',
          arabicName: '',
          isActive: true,
        ),
      );
      return;
    }

    // edit mode — load existing entity
    final id = event.id;
    if (id == null) {
      emit(const LocationFormLoadFailed('id required for edit mode'));
      return;
    }

    emit(const LocationFormLoading());
    try {
      switch (event.level) {
        case LocationLevel.governorate:
          final gov = await _loadGovernorateDetail(id);
          emit(
            LocationFormEditing(
              mode: event.mode,
              level: event.level,
              id: id,
              key: gov.key,
              arabicName: gov.displayName['ar'] ?? '',
              englishName: gov.displayName['en'],
              position: gov.position,
              isActive: gov.isActive,
              isLoadedSystemRow: gov.isSystem,
            ),
          );

        case LocationLevel.city:
          final city = await _loadCityDetail(id);
          emit(
            LocationFormEditing(
              mode: event.mode,
              level: event.level,
              id: id,
              parentId: city.governorateId,
              key: city.key,
              arabicName: city.displayName['ar'] ?? '',
              englishName: city.displayName['en'],
              position: city.position,
              isActive: city.isActive,
              isLoadedSystemRow: city.isSystem,
            ),
          );

        case LocationLevel.area:
          final area = await _loadAreaDetail(id);
          emit(
            LocationFormEditing(
              mode: event.mode,
              level: event.level,
              id: id,
              parentId: area.cityId,
              key: area.key,
              arabicName: area.displayName['ar'] ?? '',
              englishName: area.displayName['en'],
              position: area.position,
              isActive: area.isActive,
              centroidLat: area.centroidLat,
              centroidLng: area.centroidLng,
            ),
          );
      }
    } on LocationsFailure catch (failure) {
      emit(LocationFormLoadFailed(failure.message));
    } on Object catch (error) {
      emit(LocationFormLoadFailed(error.toString()));
    }
  }

  void _onKeyChanged(KeyChanged event, Emitter<LocationFormState> emit) {
    final editing = state;
    if (editing is! LocationFormEditing) return;
    emit(editing.copyWith(key: event.value));
  }

  void _onArabicNameChanged(
    ArabicNameChanged event,
    Emitter<LocationFormState> emit,
  ) {
    final editing = state;
    if (editing is! LocationFormEditing) return;
    emit(editing.copyWith(arabicName: event.value));
  }

  void _onEnglishNameChanged(
    EnglishNameChanged event,
    Emitter<LocationFormState> emit,
  ) {
    final editing = state;
    if (editing is! LocationFormEditing) return;
    emit(editing.copyWith(englishName: event.value));
  }

  void _onPositionChanged(
    PositionChanged event,
    Emitter<LocationFormState> emit,
  ) {
    final editing = state;
    if (editing is! LocationFormEditing) return;
    emit(editing.copyWith(position: () => event.value));
  }

  void _onIsActiveToggled(
    IsActiveToggled event,
    Emitter<LocationFormState> emit,
  ) {
    final editing = state;
    if (editing is! LocationFormEditing) return;
    emit(editing.copyWith(isActive: event.value));
  }

  void _onCentroidChanged(
    CentroidChanged event,
    Emitter<LocationFormState> emit,
  ) {
    final editing = state;
    if (editing is! LocationFormEditing) return;
    emit(editing.copyWith(centroidLat: event.lat, centroidLng: event.lng));
  }

  Future<void> _onSaveRequested(
    SaveRequested event,
    Emitter<LocationFormState> emit,
  ) async {
    final editing = state;
    if (editing is! LocationFormEditing || editing.isSaving) return;

    final trimmedKey = editing.key.trim();
    final arabicName = editing.arabicName.trim();

    // Defensive slug validation (primary validation is on the Form widget)
    final slugRegex = RegExp(r'^[a-z0-9][a-z0-9-]*$');
    if (trimmedKey.isEmpty ||
        arabicName.isEmpty ||
        !slugRegex.hasMatch(trimmedKey)) {
      emit(
        const LocationFormSaveFailure(
          LocationsUnknownFailure('validation failed'),
        ),
      );
      emit(editing);
      return;
    }

    // Area-only: a centroid is mandatory (DB columns are NOT NULL) and must
    // sit inside Syria's bounds (DB CHECK). Validate here so the user gets a
    // friendly message instead of a raw 23502/23514 from Postgres.
    if (editing.level == LocationLevel.area) {
      final lat = editing.centroidLat;
      final lng = editing.centroidLng;
      if (lat == null || lng == null) {
        emit(const LocationFormSaveFailure(CentroidRequiredFailure()));
        emit(editing);
        return;
      }
      if (lat < centroidLatMin ||
          lat > centroidLatMax ||
          lng < centroidLngMin ||
          lng > centroidLngMax) {
        emit(const LocationFormSaveFailure(CentroidOutOfBoundsFailure()));
        emit(editing);
        return;
      }
    }

    emit(editing.copyWith(isSaving: true));

    final displayName = <String, String>{
      'ar': arabicName,
      if (editing.englishName?.trim().isNotEmpty == true)
        'en': editing.englishName!.trim(),
    };

    try {
      switch (editing.level) {
        case LocationLevel.governorate:
          if (editing.mode == LocationFormMode.add) {
            await _createGovernorate(
              key: trimmedKey,
              displayName: displayName,
              position: editing.position,
              isActive: editing.isActive,
            );
          } else {
            await _updateGovernorate(
              editing.id!,
              key: editing.isLoadedSystemRow ? null : trimmedKey,
              displayName: displayName,
              position: editing.position,
              isActive: editing.isActive,
            );
          }

        case LocationLevel.city:
          if (editing.mode == LocationFormMode.add) {
            final parentId = editing.parentId;
            if (parentId == null) {
              emit(
                const LocationFormSaveFailure(
                  LocationsUnknownFailure('parentId required for city add'),
                ),
              );
              emit(editing.copyWith(isSaving: false));
              return;
            }
            await _createCity(
              governorateId: parentId,
              key: trimmedKey,
              displayName: displayName,
              position: editing.position,
              isActive: editing.isActive,
            );
          } else {
            await _updateCity(
              editing.id!,
              key: editing.isLoadedSystemRow ? null : trimmedKey,
              displayName: displayName,
              position: editing.position,
              isActive: editing.isActive,
            );
          }

        case LocationLevel.area:
          if (editing.mode == LocationFormMode.add) {
            final parentId = editing.parentId;
            if (parentId == null) {
              emit(
                const LocationFormSaveFailure(
                  LocationsUnknownFailure('parentId required for area add'),
                ),
              );
              emit(editing.copyWith(isSaving: false));
              return;
            }
            await _createArea(
              cityId: parentId,
              key: trimmedKey,
              displayName: displayName,
              // Non-null: guarded by the area-level validation above.
              centroidLat: editing.centroidLat!,
              centroidLng: editing.centroidLng!,
              position: editing.position,
              isActive: editing.isActive,
            );
          } else {
            await _updateArea(
              editing.id!,
              key: trimmedKey,
              displayName: displayName,
              position: editing.position,
              isActive: editing.isActive,
              // Non-null: guarded by the area-level validation above.
              centroidLat: editing.centroidLat,
              centroidLng: editing.centroidLng,
            );
          }
      }

      emit(const LocationFormSaveSuccess());
    } on KeyAlreadyUsedFailure catch (failure) {
      emit(LocationFormSaveFailure(failure));
      emit(editing.copyWith(isSaving: false));
    } on SystemRowProtectedFailure catch (failure) {
      emit(LocationFormSaveFailure(failure));
      emit(editing.copyWith(isSaving: false));
    } on NotAuthorizedFailure catch (failure) {
      emit(LocationFormSaveFailure(failure));
      emit(editing.copyWith(isSaving: false));
    } on LocationsFailure catch (failure) {
      emit(LocationFormSaveFailure(failure));
      emit(editing.copyWith(isSaving: false));
    } on Object catch (error) {
      emit(LocationFormSaveFailure(LocationsUnknownFailure(error.toString())));
      emit(editing.copyWith(isSaving: false));
    }
  }
}
