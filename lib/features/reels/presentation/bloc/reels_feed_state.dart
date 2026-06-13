part of 'reels_feed_cubit.dart';

/// Phase 029 — state machine for [ReelsFeedCubit].
///
/// `initial` → `loading` → (`loaded` | `empty` | `failure`); `loaded` →
/// `loadingMore` → `loaded` on each appended page.
enum ReelsFeedStatus { initial, loading, loaded, loadingMore, empty, failure }

class ReelsFeedState extends Equatable {
  const ReelsFeedState({
    this.status = ReelsFeedStatus.initial,
    this.reels = const <Reel>[],
    this.endReached = false,
  });

  final ReelsFeedStatus status;
  final List<Reel> reels;

  /// True once a page returned fewer rows than requested (no more pages) or an
  /// append failed.
  final bool endReached;

  ReelsFeedState copyWith({
    ReelsFeedStatus? status,
    List<Reel>? reels,
    bool? endReached,
  }) {
    return ReelsFeedState(
      status: status ?? this.status,
      reels: reels ?? this.reels,
      endReached: endReached ?? this.endReached,
    );
  }

  @override
  List<Object?> get props => [status, reels, endReached];
}
