// Phase 19 (spec/019-agencies) — T064
// AgencyQueueBloc: drives the admin agency verification queue page.
// Events: Opened / FilterChanged(status?) / LoadMore / Refresh.
// Mirrors ReportsQueueBloc (Phase 18) with AgencyStatus filter.
// Constitution IX: zero Supabase imports.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../../../../agency/domain/entities/agency_status.dart';
import '../../domain/entities/agency_verification_item.dart';
import '../../domain/usecases/load_agency_verification_queue.dart';
import 'agency_queue_state.dart';

const int _pageSize = 20;

// ─── Events ─────────────────────────────────────────────────────────────────

sealed class AgencyQueueEvent extends Equatable {
  const AgencyQueueEvent();
  @override
  List<Object?> get props => const [];
}

/// Fired once when the page first mounts.
class AgencyQueueOpened extends AgencyQueueEvent {
  const AgencyQueueOpened();
}

/// Fired when the user changes the status filter dropdown.
/// Pass null to clear the filter (or set [clearStatus] = true).
class AgencyQueueFilterChanged extends AgencyQueueEvent {
  const AgencyQueueFilterChanged({
    this.status,
    this.clearStatus = false,
  });

  final AgencyStatus? status;

  /// If true, the status filter is cleared regardless of [status].
  final bool clearStatus;

  @override
  List<Object?> get props => [status, clearStatus];
}

/// Fired by the scroll listener when the user nears the bottom of the list.
class AgencyQueueLoadMore extends AgencyQueueEvent {
  const AgencyQueueLoadMore();
}

/// Fired by the pull-to-refresh gesture; reloads from page 1.
class AgencyQueueRefresh extends AgencyQueueEvent {
  const AgencyQueueRefresh();
}

// ─── BLoC ────────────────────────────────────────────────────────────────────

@injectable
class AgencyQueueBloc extends Bloc<AgencyQueueEvent, AgencyQueueState> {
  AgencyQueueBloc(this._loadQueue) : super(const AgencyQueueState()) {
    on<AgencyQueueOpened>(_onOpened);
    on<AgencyQueueFilterChanged>(_onFilterChanged);
    on<AgencyQueueLoadMore>(_onLoadMore);
    on<AgencyQueueRefresh>(_onRefresh);
  }

  final LoadAgencyVerificationQueue _loadQueue;

  Future<void> _onOpened(
    AgencyQueueOpened event,
    Emitter<AgencyQueueState> emit,
  ) async {
    emit(state.copyWith(isLoadingFirstPage: true, clearFailure: true));
    final result = await _loadQueue(
      status: state.statusFilter,
      limit: _pageSize,
    );
    _emitFirstPageResult(result, emit);
  }

  Future<void> _onFilterChanged(
    AgencyQueueFilterChanged event,
    Emitter<AgencyQueueState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingFirstPage: true,
        clearFailure: true,
        clearCursor: true,
        statusFilter: event.status,
        clearStatusFilter: event.clearStatus,
      ),
    );
    final result = await _loadQueue(
      status: event.clearStatus ? null : (event.status ?? state.statusFilter),
      limit: _pageSize,
    );
    _emitFirstPageResult(result, emit);
  }

  Future<void> _onRefresh(
    AgencyQueueRefresh event,
    Emitter<AgencyQueueState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingFirstPage: true,
      clearFailure: true,
      clearCursor: true,
    ));
    final result = await _loadQueue(
      status: state.statusFilter,
      limit: _pageSize,
    );
    _emitFirstPageResult(result, emit);
  }

  void _emitFirstPageResult(
    Result<List<AgencyVerificationItem>> result,
    Emitter<AgencyQueueState> emit,
  ) {
    switch (result) {
      case Success<List<AgencyVerificationItem>>(:final value):
        final cursor = value.isEmpty
            ? null
            : value.last.request.submittedAt.toUtc().toIso8601String();
        emit(
          state.copyWith(
            items: value,
            nextCursor: cursor,
            isLoadingFirstPage: false,
            endReached: value.length < _pageSize,
            clearFailure: true,
          ),
        );
      case FailureResult<List<AgencyVerificationItem>>(:final failure):
        emit(state.copyWith(isLoadingFirstPage: false, failure: failure));
    }
  }

  Future<void> _onLoadMore(
    AgencyQueueLoadMore event,
    Emitter<AgencyQueueState> emit,
  ) async {
    if (state.isLoadingFirstPage ||
        state.isLoadingNextPage ||
        state.endReached ||
        state.nextCursor == null) {
      return;
    }
    emit(state.copyWith(isLoadingNextPage: true, clearFailure: true));
    final result = await _loadQueue(
      status: state.statusFilter,
      cursor: state.nextCursor,
      limit: _pageSize,
    );
    switch (result) {
      case Success<List<AgencyVerificationItem>>(:final value):
        final accumulated = [...state.items, ...value];
        final cursor = value.isEmpty
            ? state.nextCursor
            : value.last.request.submittedAt.toUtc().toIso8601String();
        emit(
          state.copyWith(
            items: accumulated,
            nextCursor: cursor,
            isLoadingNextPage: false,
            endReached: value.length < _pageSize,
          ),
        );
      case FailureResult<List<AgencyVerificationItem>>(:final failure):
        emit(state.copyWith(isLoadingNextPage: false, failure: failure));
    }
  }
}
