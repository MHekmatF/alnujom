import 'package:equatable/equatable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/cursor.dart';
import '../../domain/entities/home_listing_card.dart';

/// Phase 13 — state machine for [HomeBloc] per FR-014.
///
/// Transitions:
/// - `initial` → `loading` on `HomeFeedLoadRequested`.
/// - `loading` → `success` (page non-empty + listings populated) or
///   `success` (page empty + listings: []).
/// - `loading` → `error` on transport failure.
/// - `success` → `loadingMore` on `HomeFeedNextPageRequested`.
/// - `loadingMore` → `success` (rows appended; endReached if <20 rows).
/// - `success` → `refreshing` on `HomeFeedRefreshRequested`.
/// - `refreshing` → `success` (cursor cleared, list replaced).
/// - `error` → `loading` on retry (`HomeFeedLoadRequested` re-issued).
///
/// While `status ∈ {loadingMore, refreshing}`, the BLoC ignores subsequent
/// identical events to prevent duplicate concurrent fetches.
enum HomeFeedStatus {
  initial,
  loading,
  success,
  error,
  loadingMore,
  refreshing,
}

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeFeedStatus.initial,
    this.listings = const <HomeListingCard>[],
    this.cursor,
    this.failure,
    this.endReached = false,
  });

  final HomeFeedStatus status;
  final List<HomeListingCard> listings;
  final Cursor? cursor;
  final Failure? failure;

  /// True when the most recent page returned <20 rows. The infinite-scroll
  /// trigger guards against further `HomeFeedNextPageRequested` events while
  /// this is true, and the page renders the `home_no_more_listings`
  /// sentinel.
  final bool endReached;

  HomeState copyWith({
    HomeFeedStatus? status,
    List<HomeListingCard>? listings,
    Object? cursor = _sentinel,
    Object? failure = _sentinel,
    bool? endReached,
  }) {
    return HomeState(
      status: status ?? this.status,
      listings: listings ?? this.listings,
      cursor: identical(cursor, _sentinel) ? this.cursor : cursor as Cursor?,
      failure: identical(failure, _sentinel)
          ? this.failure
          : failure as Failure?,
      endReached: endReached ?? this.endReached,
    );
  }

  @override
  List<Object?> get props => [status, listings, cursor, failure, endReached];
}

const Object _sentinel = Object();
