import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/nearby_amenity.dart';
import '../../domain/repositories/nearby_amenities_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum NearbyAmenitiesStatus { initial, loading, loaded, empty, error }

/// Spec 028 — state for the listing-details "Nearby" amenities section.
class NearbyAmenitiesState extends Equatable {
  const NearbyAmenitiesState({
    this.status = NearbyAmenitiesStatus.initial,
    this.amenities = const [],
  });

  final NearbyAmenitiesStatus status;

  /// Nearest-first, capped by the datasource (~10).
  final List<NearbyAmenity> amenities;

  NearbyAmenitiesState copyWith({
    NearbyAmenitiesStatus? status,
    List<NearbyAmenity>? amenities,
  }) {
    return NearbyAmenitiesState(
      status: status ?? this.status,
      amenities: amenities ?? this.amenities,
    );
  }

  @override
  List<Object?> get props => [status, amenities];
}

// ─── Cubit ────────────────────────────────────────────────────────────────────

/// Spec 028 — drives the listing-details "Nearby" amenities chips.
///
/// Factory-scoped (one per detail page); a simple load-once cubit fired by the
/// section widget with the listing's coordinates. Error and empty both leave
/// the section collapsed — Overpass is strictly best-effort.
@injectable
class NearbyAmenitiesCubit extends Cubit<NearbyAmenitiesState> {
  NearbyAmenitiesCubit(this._repository) : super(const NearbyAmenitiesState());

  final NearbyAmenitiesRepository _repository;

  Future<void> load({
    required String listingId,
    required double latitude,
    required double longitude,
  }) async {
    if (state.status == NearbyAmenitiesStatus.loading) return;
    emit(state.copyWith(status: NearbyAmenitiesStatus.loading));

    final result = await _repository.fetchNearby(
      listingId: listingId,
      latitude: latitude,
      longitude: longitude,
    );

    switch (result) {
      case Success<List<NearbyAmenity>>():
        final amenities = result.value;
        emit(
          state.copyWith(
            status: amenities.isEmpty
                ? NearbyAmenitiesStatus.empty
                : NearbyAmenitiesStatus.loaded,
            amenities: amenities,
          ),
        );
      case FailureResult<List<NearbyAmenity>>():
        emit(state.copyWith(status: NearbyAmenitiesStatus.error));
    }
  }
}
