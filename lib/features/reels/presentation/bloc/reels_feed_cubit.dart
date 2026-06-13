import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/reel.dart';
import '../../domain/repositories/reels_repository.dart';
import '../../domain/usecases/load_reels.dart';

part 'reels_feed_state.dart';

/// Phase 029 (Reels W4) — cubit driving the fullscreen vertical reels feed.
/// Keyset-paginates over `(published_at, id)` DESC via [ReelCursor]; appended
/// pages extend [ReelsFeedState.reels] in place.
///
/// Not a singleton — scoped to [ReelsFeedPage]'s own [BlocProvider]. May be
/// seeded with the rail's already-loaded first page so the feed paints
/// instantly.
@injectable
class ReelsFeedCubit extends Cubit<ReelsFeedState> {
  ReelsFeedCubit(this._loadReels) : super(const ReelsFeedState());

  final LoadReels _loadReels;

  static const int feedPageSize = 10;

  /// Seeds the feed with a pre-loaded first page (the rail's reels). Marks the
  /// end as reached when the seed is shorter than a full page so we don't fire
  /// a redundant first fetch.
  void seed(List<Reel> initial) {
    if (initial.isEmpty) return;
    emit(
      ReelsFeedState(
        status: ReelsFeedStatus.loaded,
        reels: List<Reel>.unmodifiable(initial),
        endReached: initial.length < feedPageSize,
      ),
    );
  }

  /// Loads the first page from scratch (when no seed was provided). No-op if
  /// reels are already present.
  Future<void> loadInitial({required Locale locale}) async {
    if (state.reels.isNotEmpty) return;
    emit(const ReelsFeedState(status: ReelsFeedStatus.loading));
    final result = await _loadReels(limit: feedPageSize, locale: locale);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(
          ReelsFeedState(
            status: value.isEmpty
                ? ReelsFeedStatus.empty
                : ReelsFeedStatus.loaded,
            reels: List<Reel>.unmodifiable(value),
            endReached: value.length < feedPageSize,
          ),
        );
      case FailureResult():
        emit(const ReelsFeedState(status: ReelsFeedStatus.failure));
    }
  }

  /// Appends the next keyset page. Idempotent against concurrent triggers
  /// (PageView scroll can fire this repeatedly) and a no-op once the end is
  /// reached or nothing is loaded yet.
  Future<void> loadMore({required Locale locale}) async {
    if (state.status == ReelsFeedStatus.loadingMore ||
        state.endReached ||
        state.reels.isEmpty) {
      return;
    }
    emit(state.copyWith(status: ReelsFeedStatus.loadingMore));
    final cursor = ReelCursor.fromLast(state.reels.last);
    final result = await _loadReels(
      limit: feedPageSize,
      before: cursor,
      locale: locale,
    );
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(
          state.copyWith(
            status: ReelsFeedStatus.loaded,
            reels: List<Reel>.unmodifiable([...state.reels, ...value]),
            endReached: value.length < feedPageSize,
          ),
        );
      case FailureResult():
        // A failed append is non-fatal: keep what we have, stop paginating so
        // we don't hammer a failing endpoint.
        emit(state.copyWith(status: ReelsFeedStatus.loaded, endReached: true));
    }
  }
}
