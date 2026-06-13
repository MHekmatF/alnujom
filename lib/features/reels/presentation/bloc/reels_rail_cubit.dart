import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/reel.dart';
import '../../domain/usecases/load_reels.dart';

part 'reels_rail_state.dart';

/// Phase 029 (Reels W4) — cubit driving the home "Reels" rail. Loads only the
/// FIRST page of reels once when Home opens; on empty OR failure the rail hides
/// itself entirely (reels are a non-blocking enhancement to the home feed).
///
/// Not a singleton — scoped to the rail's own [BlocProvider] inside [ReelsRail].
@injectable
class ReelsRailCubit extends Cubit<ReelsRailState> {
  ReelsRailCubit(this._loadReels) : super(const ReelsRailState());

  final LoadReels _loadReels;

  /// First page used to seed the fullscreen feed when the user taps a card,
  /// so the feed paints instantly without a second round-trip.
  static const int railPageSize = 10;

  Future<void> load({required Locale locale}) async {
    emit(const ReelsRailState(status: ReelsRailStatus.loading));
    final result = await _loadReels(limit: railPageSize, locale: locale);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(
          value.isEmpty
              ? const ReelsRailState(status: ReelsRailStatus.empty)
              : ReelsRailState(
                  status: ReelsRailStatus.loaded,
                  reels: value,
                ),
        );
      case FailureResult():
        emit(const ReelsRailState(status: ReelsRailStatus.failure));
    }
  }
}
