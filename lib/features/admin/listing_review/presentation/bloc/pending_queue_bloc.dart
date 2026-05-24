import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../domain/entities/pending_listing_summary.dart';
import '../../domain/repositories/listing_review_repository.dart';
import '../../domain/usecases/load_pending_queue.dart';

const int _pageSize = 20;

// ─── Events ─────────────────────────────────────────────────────────────

sealed class PendingQueueEvent extends Equatable {
  const PendingQueueEvent();
  @override
  List<Object?> get props => const [];
}

class PendingQueueLoadFirstPage extends PendingQueueEvent {
  const PendingQueueLoadFirstPage();
}

class PendingQueueLoadNextPage extends PendingQueueEvent {
  const PendingQueueLoadNextPage();
}

class PendingQueueRefresh extends PendingQueueEvent {
  const PendingQueueRefresh();
}

// ─── State ──────────────────────────────────────────────────────────────

class PendingQueueState extends Equatable {
  const PendingQueueState({
    this.listings = const <PendingListingSummary>[],
    this.nextCursor,
    this.isLoadingFirstPage = false,
    this.isLoadingNextPage = false,
    this.failure,
    this.endReached = false,
  });

  final List<PendingListingSummary> listings;
  final PendingQueueCursor? nextCursor;
  final bool isLoadingFirstPage;
  final bool isLoadingNextPage;
  final Failure? failure;
  final bool endReached;

  bool get isEmpty =>
      listings.isEmpty &&
      !isLoadingFirstPage &&
      !isLoadingNextPage &&
      failure == null;

  PendingQueueState copyWith({
    List<PendingListingSummary>? listings,
    PendingQueueCursor? nextCursor,
    bool clearCursor = false,
    bool? isLoadingFirstPage,
    bool? isLoadingNextPage,
    Failure? failure,
    bool clearFailure = false,
    bool? endReached,
  }) {
    return PendingQueueState(
      listings: listings ?? this.listings,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      failure: clearFailure ? null : (failure ?? this.failure),
      endReached: endReached ?? this.endReached,
    );
  }

  @override
  List<Object?> get props => [
    listings,
    nextCursor,
    isLoadingFirstPage,
    isLoadingNextPage,
    failure,
    endReached,
  ];
}

// ─── BLoC ───────────────────────────────────────────────────────────────

@injectable
class PendingQueueBloc extends Bloc<PendingQueueEvent, PendingQueueState> {
  PendingQueueBloc(this._loadPendingQueue) : super(const PendingQueueState()) {
    on<PendingQueueLoadFirstPage>(_onLoadFirstPage);
    on<PendingQueueLoadNextPage>(_onLoadNextPage);
    on<PendingQueueRefresh>(_onRefresh);
  }

  final LoadPendingQueueUseCase _loadPendingQueue;

  Future<void> _onLoadFirstPage(
    PendingQueueLoadFirstPage event,
    Emitter<PendingQueueState> emit,
  ) async {
    emit(state.copyWith(isLoadingFirstPage: true, clearFailure: true));
    final result = await _loadPendingQueue.call(limit: _pageSize);
    _emitFirstPageResult(result, emit);
  }

  Future<void> _onRefresh(
    PendingQueueRefresh event,
    Emitter<PendingQueueState> emit,
  ) async {
    emit(state.copyWith(isLoadingFirstPage: true, clearFailure: true));
    final result = await _loadPendingQueue.call(limit: _pageSize);
    _emitFirstPageResult(result, emit);
  }

  void _emitFirstPageResult(
    Result<List<PendingListingSummary>> result,
    Emitter<PendingQueueState> emit,
  ) {
    switch (result) {
      case Success<List<PendingListingSummary>>(:final value):
        final cursor = value.isEmpty
            ? null
            : PendingQueueCursor(
                lastSubmittedAt: value.last.submittedAt,
                lastId: value.last.id,
              );
        emit(
          PendingQueueState(
            listings: value,
            nextCursor: cursor,
            isLoadingFirstPage: false,
            endReached: value.length < _pageSize,
          ),
        );
      case FailureResult<List<PendingListingSummary>>(:final failure):
        emit(state.copyWith(isLoadingFirstPage: false, failure: failure));
    }
  }

  Future<void> _onLoadNextPage(
    PendingQueueLoadNextPage event,
    Emitter<PendingQueueState> emit,
  ) async {
    if (state.isLoadingFirstPage ||
        state.isLoadingNextPage ||
        state.endReached ||
        state.nextCursor == null) {
      return;
    }
    emit(state.copyWith(isLoadingNextPage: true, clearFailure: true));
    final result = await _loadPendingQueue.call(
      cursor: state.nextCursor,
      limit: _pageSize,
    );
    switch (result) {
      case Success<List<PendingListingSummary>>(:final value):
        final accumulated = [...state.listings, ...value];
        final cursor = value.isEmpty
            ? state.nextCursor
            : PendingQueueCursor(
                lastSubmittedAt: value.last.submittedAt,
                lastId: value.last.id,
              );
        emit(
          state.copyWith(
            listings: accumulated,
            nextCursor: cursor,
            isLoadingNextPage: false,
            endReached: value.length < _pageSize,
          ),
        );
      case FailureResult<List<PendingListingSummary>>(:final failure):
        emit(state.copyWith(isLoadingNextPage: false, failure: failure));
    }
  }
}
