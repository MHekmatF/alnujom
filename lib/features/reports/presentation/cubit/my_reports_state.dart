// lib/features/reports/presentation/cubit/my_reports_state.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T045).
part of 'my_reports_bloc.dart';

sealed class MyReportsState {
  const MyReportsState();
}

final class MyReportsLoading extends MyReportsState {
  const MyReportsLoading();
}

final class MyReportsLoaded extends MyReportsState {
  const MyReportsLoaded({required this.items, required this.hasMore});

  final List<Report> items;
  final bool hasMore;
}

final class MyReportsError extends MyReportsState {
  const MyReportsError(this.failure);

  final Object failure;
}
