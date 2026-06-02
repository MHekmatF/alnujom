// Phase 20 (spec/020-admin-dashboard) — T023
// AuditLogCubit: drives the read-only paginated audit-log viewer.
// load() (on entry) and refresh() share one first-page path; loadMore()
// appends the next bounded page. No Timer, no Realtime (FR-020).
// Constitution IX: zero Supabase imports.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/usecases/load_audit_log_page.dart';
import 'audit_log_state.dart';

const int _pageSize = 30;

@injectable
class AuditLogCubit extends Cubit<AuditLogState> {
  AuditLogCubit(this._loadAuditLogPage) : super(const AuditLogState());

  final LoadAuditLogPage _loadAuditLogPage;

  /// First-page load on entry.
  Future<void> load() => _loadFirstPage();

  /// Pull-to-refresh; reloads from page 1.
  Future<void> refresh() => _loadFirstPage();

  Future<void> _loadFirstPage() async {
    emit(
      state.copyWith(
        isLoadingFirstPage: true,
        clearFailure: true,
        clearCursor: true,
      ),
    );
    final result = await _loadAuditLogPage(limit: _pageSize);
    if (isClosed) return;
    switch (result) {
      case Success<List<AuditLogEntry>>(:final value):
        emit(
          state.copyWith(
            items: value,
            nextCursor: _cursorFrom(value, fallback: null),
            isLoadingFirstPage: false,
            endReached: value.length < _pageSize,
            clearFailure: true,
          ),
        );
      case FailureResult<List<AuditLogEntry>>(:final failure):
        emit(state.copyWith(isLoadingFirstPage: false, failure: failure));
    }
  }

  /// Appends the next bounded page when the user nears the list bottom.
  Future<void> loadMore() async {
    if (state.isLoadingFirstPage ||
        state.isLoadingNextPage ||
        state.endReached ||
        state.nextCursor == null) {
      return;
    }
    emit(state.copyWith(isLoadingNextPage: true, clearFailure: true));
    final result = await _loadAuditLogPage(
      cursor: state.nextCursor,
      limit: _pageSize,
    );
    if (isClosed) return;
    switch (result) {
      case Success<List<AuditLogEntry>>(:final value):
        emit(
          state.copyWith(
            items: [...state.items, ...value],
            nextCursor: _cursorFrom(value, fallback: state.nextCursor),
            isLoadingNextPage: false,
            endReached: value.length < _pageSize,
          ),
        );
      case FailureResult<List<AuditLogEntry>>(:final failure):
        emit(state.copyWith(isLoadingNextPage: false, failure: failure));
    }
  }

  String? _cursorFrom(List<AuditLogEntry> page, {required String? fallback}) {
    if (page.isEmpty) return fallback;
    return page.last.createdAt.toUtc().toIso8601String();
  }
}
