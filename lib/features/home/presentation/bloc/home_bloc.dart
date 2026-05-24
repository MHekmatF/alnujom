import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/cursor.dart';
import '../../domain/usecases/load_home_feed.dart';
import 'home_event.dart';
import 'home_state.dart';

const int _pageSize = 20;

/// Phase 13 — BLoC driving HomePage per FR-014 + contracts/
/// phase13-home-page-composition.md.
///
/// Cursor pagination via R-62 (corrected): each next-page call passes
/// `Cursor.fromLastCard(state.listings.last)`. Pull-to-refresh discards the
/// cursor and replaces the list.
///
/// State machine guards against duplicate concurrent fetches:
/// - `HomeFeedNextPageRequested` is ignored while `status == loadingMore` or
///   `status == refreshing` or `endReached` is true.
/// - `HomeFeedRefreshRequested` is ignored while `status == refreshing`.
/// - `HomeFeedLoadRequested` always processes (used for initial + retry).
@injectable
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(this._loadHomeFeed) : super(const HomeState()) {
    on<HomeFeedLoadRequested>(_onLoad);
    on<HomeFeedNextPageRequested>(_onNextPage);
    on<HomeFeedRefreshRequested>(_onRefresh);
  }

  final LoadHomeFeed _loadHomeFeed;

  Future<void> _onLoad(
    HomeFeedLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      status: HomeFeedStatus.loading,
      failure: null,
    ));
    final result = await _loadHomeFeed(locale: event.locale);
    switch (result) {
      case Success(:final value):
        final endReached = value.length < _pageSize;
        emit(state.copyWith(
          status: HomeFeedStatus.success,
          listings: value,
          cursor: value.isEmpty ? null : Cursor.fromLastCard(value.last),
          endReached: endReached,
          failure: null,
        ));
      case FailureResult(:final failure):
        emit(state.copyWith(
          status: HomeFeedStatus.error,
          failure: failure,
        ));
    }
  }

  Future<void> _onNextPage(
    HomeFeedNextPageRequested event,
    Emitter<HomeState> emit,
  ) async {
    // Guard against duplicate concurrent fetches per FR-014 state-machine
    // contract — ignore when already loading more, refreshing, or at end.
    if (state.status == HomeFeedStatus.loadingMore ||
        state.status == HomeFeedStatus.refreshing ||
        state.endReached ||
        state.listings.isEmpty) {
      return;
    }
    emit(state.copyWith(status: HomeFeedStatus.loadingMore, failure: null));
    final result = await _loadHomeFeed(
      cursor: state.cursor,
      locale: event.locale,
    );
    switch (result) {
      case Success(:final value):
        final newListings = [...state.listings, ...value];
        final endReached = value.length < _pageSize;
        emit(state.copyWith(
          status: HomeFeedStatus.success,
          listings: newListings,
          cursor: newListings.isEmpty
              ? null
              : Cursor.fromLastCard(newListings.last),
          endReached: endReached,
          failure: null,
        ));
      case FailureResult(:final failure):
        // Surface the failure but preserve the existing list so the UI can
        // show a non-blocking error banner + retry without losing scroll
        // position. The page renders `loadingMore`-state spinner or the
        // sentinel based on `endReached`; for next-page failures we revert
        // to `success` and expose the failure for an inline toast.
        emit(state.copyWith(
          status: HomeFeedStatus.success,
          failure: failure,
        ));
    }
  }

  Future<void> _onRefresh(
    HomeFeedRefreshRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.status == HomeFeedStatus.refreshing) return;
    emit(state.copyWith(status: HomeFeedStatus.refreshing, failure: null));
    final result = await _loadHomeFeed(locale: event.locale);
    switch (result) {
      case Success(:final value):
        final endReached = value.length < _pageSize;
        emit(state.copyWith(
          status: HomeFeedStatus.success,
          listings: value,
          cursor: value.isEmpty ? null : Cursor.fromLastCard(value.last),
          endReached: endReached,
          failure: null,
        ));
      case FailureResult(:final failure):
        emit(state.copyWith(
          status: HomeFeedStatus.success,
          failure: failure,
        ));
    }
  }
}
