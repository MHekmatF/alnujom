// lib/features/reports/presentation/cubit/my_reports_bloc.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T045).
// Paginated BLoC for MyReportsPage.
// Events: Opened / Refresh / LoadMore → LoadMyReports use case.
// Cursor on created_at DESC, limit 30. Mirrors FavoritesPageBloc (R-117).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/report.dart';
import '../../domain/usecases/load_my_reports.dart';

part 'my_reports_state.dart';

// ---------------------------------------------------------------------------
// Events (sealed, defined locally — no separate file needed for 3 variants)
// ---------------------------------------------------------------------------

sealed class MyReportsEvent {
  const MyReportsEvent();
}

final class MyReportsOpened extends MyReportsEvent {
  const MyReportsOpened();
}

final class MyReportsRefreshRequested extends MyReportsEvent {
  const MyReportsRefreshRequested();
}

final class MyReportsMoreLoaded extends MyReportsEvent {
  const MyReportsMoreLoaded();
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------

/// Page-scoped BLoC loading the reporter's own reports from `public.v_reports`
/// (newest-first, cursor-paginated on created_at DESC).
///
/// Registered as @injectable (one instance per page).
@injectable
class MyReportsBloc extends Bloc<MyReportsEvent, MyReportsState> {
  MyReportsBloc(this._loadMyReports) : super(const MyReportsLoading()) {
    on<MyReportsOpened>(_onOpened);
    on<MyReportsRefreshRequested>(_onRefresh);
    on<MyReportsMoreLoaded>(_onMoreLoaded);
  }

  final LoadMyReports _loadMyReports;

  static const int _pageSize = 30;

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onOpened(
    MyReportsOpened event,
    Emitter<MyReportsState> emit,
  ) async {
    emit(const MyReportsLoading());
    await _fetchFirstPage(emit);
  }

  Future<void> _onRefresh(
    MyReportsRefreshRequested event,
    Emitter<MyReportsState> emit,
  ) async {
    emit(const MyReportsLoading());
    await _fetchFirstPage(emit);
  }

  Future<void> _onMoreLoaded(
    MyReportsMoreLoaded event,
    Emitter<MyReportsState> emit,
  ) async {
    final current = state;
    if (current is! MyReportsLoaded || !current.hasMore) return;

    // Cursor: ISO-8601 `created_at` of the last item.
    final cursor = current.items.isNotEmpty
        ? current.items.last.createdAt.toIso8601String()
        : null;

    final result = await _loadMyReports(cursor: cursor, limit: _pageSize);

    if (result is Success<List<Report>>) {
      final newItems = result.value;
      emit(
        MyReportsLoaded(
          items: [...current.items, ...newItems],
          hasMore: newItems.length == _pageSize,
        ),
      );
    }
    // On pagination error: silently keep current page (user can pull-refresh).
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _fetchFirstPage(Emitter<MyReportsState> emit) async {
    final result = await _loadMyReports(cursor: null, limit: _pageSize);
    switch (result) {
      case Success<List<Report>>(:final value):
        emit(
          MyReportsLoaded(
            items: value,
            hasMore: value.length == _pageSize,
          ),
        );
      case FailureResult<List<Report>>(:final failure):
        emit(MyReportsError(failure));
    }
  }
}
