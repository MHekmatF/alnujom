// Phase 18 (spec/018-reports-moderation) — T053
// ReportsQueueBloc: drives the admin moderation queue page.
// Events: Opened / FilterChanged(status?, reason?) / LoadMore / Refresh.
// Mirrors PendingQueueBloc (Phase 12) with added filter support.
// Constitution IX: zero Supabase imports.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';
import '../../domain/entities/report_queue_item.dart';
import '../../domain/usecases/load_reports_queue.dart';
import 'reports_queue_state.dart';

const int _pageSize = 20;

// ─── Events ─────────────────────────────────────────────────────────────────

sealed class ReportsQueueEvent extends Equatable {
  const ReportsQueueEvent();
  @override
  List<Object?> get props => const [];
}

/// Fired once when the page first mounts.
class ReportsQueueOpened extends ReportsQueueEvent {
  const ReportsQueueOpened();
}

/// Fired when the user changes a filter dropdown.
/// Pass null for either filter to clear it.
class ReportsQueueFilterChanged extends ReportsQueueEvent {
  const ReportsQueueFilterChanged({this.status, this.reason, this.clearStatus = false, this.clearReason = false});

  final ReportStatus? status;
  final ReportReason? reason;

  /// If true, the status filter is cleared regardless of [status].
  final bool clearStatus;

  /// If true, the reason filter is cleared regardless of [reason].
  final bool clearReason;

  @override
  List<Object?> get props => [status, reason, clearStatus, clearReason];
}

/// Fired by the scroll listener when the user nears the bottom of the list.
class ReportsQueueLoadMore extends ReportsQueueEvent {
  const ReportsQueueLoadMore();
}

/// Fired by the pull-to-refresh gesture; reloads from page 1.
class ReportsQueueRefresh extends ReportsQueueEvent {
  const ReportsQueueRefresh();
}

// ─── BLoC ────────────────────────────────────────────────────────────────────

@injectable
class ReportsQueueBloc extends Bloc<ReportsQueueEvent, ReportsQueueState> {
  ReportsQueueBloc(this._loadReportsQueue)
      : super(const ReportsQueueState()) {
    on<ReportsQueueOpened>(_onOpened);
    on<ReportsQueueFilterChanged>(_onFilterChanged);
    on<ReportsQueueLoadMore>(_onLoadMore);
    on<ReportsQueueRefresh>(_onRefresh);
  }

  final LoadReportsQueue _loadReportsQueue;

  Future<void> _onOpened(
    ReportsQueueOpened event,
    Emitter<ReportsQueueState> emit,
  ) async {
    emit(state.copyWith(isLoadingFirstPage: true, clearFailure: true));
    final result = await _loadReportsQueue(
      status: state.statusFilter,
      reason: state.reasonFilter,
      limit: _pageSize,
    );
    _emitFirstPageResult(result, emit);
  }

  Future<void> _onFilterChanged(
    ReportsQueueFilterChanged event,
    Emitter<ReportsQueueState> emit,
  ) async {
    // Apply filter change, reset to page 1.
    emit(
      state.copyWith(
        isLoadingFirstPage: true,
        clearFailure: true,
        clearCursor: true,
        statusFilter: event.status,
        clearStatusFilter: event.clearStatus,
        reasonFilter: event.reason,
        clearReasonFilter: event.clearReason,
      ),
    );
    final result = await _loadReportsQueue(
      status: event.clearStatus ? null : (event.status ?? state.statusFilter),
      reason: event.clearReason ? null : (event.reason ?? state.reasonFilter),
      limit: _pageSize,
    );
    _emitFirstPageResult(result, emit);
  }

  Future<void> _onRefresh(
    ReportsQueueRefresh event,
    Emitter<ReportsQueueState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingFirstPage: true,
      clearFailure: true,
      clearCursor: true,
    ));
    final result = await _loadReportsQueue(
      status: state.statusFilter,
      reason: state.reasonFilter,
      limit: _pageSize,
    );
    _emitFirstPageResult(result, emit);
  }

  void _emitFirstPageResult(
    Result<List<ReportQueueItem>> result,
    Emitter<ReportsQueueState> emit,
  ) {
    switch (result) {
      case Success<List<ReportQueueItem>>(:final value):
        final cursor = value.isEmpty
            ? null
            : value.last.createdAt.toUtc().toIso8601String();
        emit(
          state.copyWith(
            items: value,
            nextCursor: cursor,
            isLoadingFirstPage: false,
            endReached: value.length < _pageSize,
            clearFailure: true,
          ),
        );
      case FailureResult<List<ReportQueueItem>>(:final failure):
        emit(state.copyWith(isLoadingFirstPage: false, failure: failure));
    }
  }

  Future<void> _onLoadMore(
    ReportsQueueLoadMore event,
    Emitter<ReportsQueueState> emit,
  ) async {
    if (state.isLoadingFirstPage ||
        state.isLoadingNextPage ||
        state.endReached ||
        state.nextCursor == null) {
      return;
    }
    emit(state.copyWith(isLoadingNextPage: true, clearFailure: true));
    final result = await _loadReportsQueue(
      status: state.statusFilter,
      reason: state.reasonFilter,
      cursor: state.nextCursor,
      limit: _pageSize,
    );
    switch (result) {
      case Success<List<ReportQueueItem>>(:final value):
        final accumulated = [...state.items, ...value];
        final cursor = value.isEmpty
            ? state.nextCursor
            : value.last.createdAt.toUtc().toIso8601String();
        emit(
          state.copyWith(
            items: accumulated,
            nextCursor: cursor,
            isLoadingNextPage: false,
            endReached: value.length < _pageSize,
          ),
        );
      case FailureResult<List<ReportQueueItem>>(:final failure):
        emit(state.copyWith(isLoadingNextPage: false, failure: failure));
    }
  }
}
