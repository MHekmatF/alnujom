import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/home_listing_card.dart';
import '../../domain/usecases/load_featured_listings.dart';

part 'featured_listings_state.dart';

/// Phase 25 (featured-listings treatment) — cubit driving the home
/// "✨ عقارات مميّزة" carousel. Loads the currently-featured listings once when
/// Home opens; on empty OR failure the section hides itself entirely (featured
/// is a non-blocking enhancement to the regular feed).
///
/// Not a singleton — scoped to the HomePage `BlocProvider`, mirroring
/// [HomeBloc]'s page-scoped lifecycle.
@injectable
class FeaturedListingsCubit extends Cubit<FeaturedListingsState> {
  FeaturedListingsCubit(this._loadFeaturedListings)
    : super(const FeaturedListingsState());

  final LoadFeaturedListings _loadFeaturedListings;

  /// Loads (or reloads) the featured listings for [locale]. Emits
  /// `loading` → (`loaded` | `empty` | `failure`).
  ///
  /// On a *reload* (pull-to-refresh) the currently-loaded listings are carried
  /// through the `loading` phase so the home featured rail keeps its content
  /// and fixed height instead of collapsing to zero and snapping back — which
  /// otherwise jumps the whole feed while the refresh is in flight.
  Future<void> load({required Locale locale}) async {
    emit(
      FeaturedListingsState(
        status: FeaturedListingsStatus.loading,
        listings: state.listings,
      ),
    );
    final result = await _loadFeaturedListings(locale: locale);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        if (value.isEmpty) {
          emit(
            const FeaturedListingsState(
              status: FeaturedListingsStatus.empty,
            ),
          );
        } else {
          emit(
            FeaturedListingsState(
              status: FeaturedListingsStatus.loaded,
              listings: value,
            ),
          );
        }
      case FailureResult():
        emit(
          const FeaturedListingsState(
            status: FeaturedListingsStatus.failure,
          ),
        );
    }
  }
}
