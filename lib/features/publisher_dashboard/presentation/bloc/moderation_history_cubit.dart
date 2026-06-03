import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/moderation_history_entry.dart';
import '../../domain/usecases/load_moderation_history.dart';
import 'moderation_history_state.dart';

/// Phase 12 / US6 — Cubit driving the publisher-facing moderation history page.
///
/// Loads the full chronological status history for a single listing via
/// [LoadModerationHistoryUseCase] and exposes [ModerationHistoryState] for the
/// page widget to render.
///
/// Server-side RLS on `public.listing_status_history` enforces
/// `publisher_user_id = auth.uid()` — no extra owner gate needed here.
@injectable
class ModerationHistoryCubit extends Cubit<ModerationHistoryState> {
  ModerationHistoryCubit(this._loadHistory)
    : super(const ModerationHistoryInitial());

  final LoadModerationHistoryUseCase _loadHistory;

  /// Load moderation history for [listingId]. Emits loading → loaded/error.
  Future<void> load(String listingId) async {
    emit(const ModerationHistoryLoading());
    final result = await _loadHistory(listingId);
    if (isClosed) return;
    switch (result) {
      case Success<List<ModerationHistoryEntry>>(:final value):
        emit(ModerationHistoryLoaded(value));
      case FailureResult<List<ModerationHistoryEntry>>(:final failure):
        emit(ModerationHistoryError(failure));
    }
  }
}
