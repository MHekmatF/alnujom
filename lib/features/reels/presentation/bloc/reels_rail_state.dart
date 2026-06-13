part of 'reels_rail_cubit.dart';

/// Phase 029 — state machine for [ReelsRailCubit].
///
/// `initial` → `loading` → (`loaded` non-empty | `empty` | `failure`). The rail
/// renders ONLY in `loaded`; `empty` and `failure` both hide the section.
enum ReelsRailStatus { initial, loading, loaded, empty, failure }

class ReelsRailState extends Equatable {
  const ReelsRailState({
    this.status = ReelsRailStatus.initial,
    this.reels = const <Reel>[],
  });

  final ReelsRailStatus status;
  final List<Reel> reels;

  @override
  List<Object?> get props => [status, reels];
}
