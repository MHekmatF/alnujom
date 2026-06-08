part of 'featured_listings_cubit.dart';

/// Phase 25 — state machine for [FeaturedListingsCubit].
///
/// Transitions:
/// - `initial` → `loading` on [FeaturedListingsCubit.load].
/// - `loading` → `loaded` (non-empty) | `empty` (zero featured) | `failure`.
///
/// The home carousel renders ONLY in the `loaded` state; `empty` and `failure`
/// both hide the section entirely (featured is a non-blocking enhancement).
enum FeaturedListingsStatus { initial, loading, loaded, empty, failure }

class FeaturedListingsState extends Equatable {
  const FeaturedListingsState({
    this.status = FeaturedListingsStatus.initial,
    this.listings = const <HomeListingCard>[],
  });

  final FeaturedListingsStatus status;
  final List<HomeListingCard> listings;

  @override
  List<Object?> get props => [status, listings];
}
