// Phase 18 (spec/018-reports-moderation) — T053
// ReportsQueueState: state for the admin moderation queue BLoC.
// Mirrors PendingQueueState from Phase 12 with status/reason filter fields.
// Constitution IX: zero Supabase imports.
import 'package:equatable/equatable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';
import '../../domain/entities/report_queue_item.dart';

class ReportsQueueState extends Equatable {
  const ReportsQueueState({
    this.items = const <ReportQueueItem>[],
    this.nextCursor,
    this.isLoadingFirstPage = false,
    this.isLoadingNextPage = false,
    this.failure,
    this.endReached = false,
    this.statusFilter,
    this.reasonFilter,
  });

  final List<ReportQueueItem> items;

  /// Opaque ISO-8601 cursor for the next page; null on the first page or when
  /// end is reached.
  final String? nextCursor;

  final bool isLoadingFirstPage;
  final bool isLoadingNextPage;
  final Failure? failure;
  final bool endReached;

  /// Active status filter (null = all statuses).
  final ReportStatus? statusFilter;

  /// Active reason filter (null = all reasons).
  final ReportReason? reasonFilter;

  bool get isEmpty =>
      items.isEmpty &&
      !isLoadingFirstPage &&
      !isLoadingNextPage &&
      failure == null;

  ReportsQueueState copyWith({
    List<ReportQueueItem>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingFirstPage,
    bool? isLoadingNextPage,
    Failure? failure,
    bool clearFailure = false,
    bool? endReached,
    ReportStatus? statusFilter,
    bool clearStatusFilter = false,
    ReportReason? reasonFilter,
    bool clearReasonFilter = false,
  }) {
    return ReportsQueueState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      failure: clearFailure ? null : (failure ?? this.failure),
      endReached: endReached ?? this.endReached,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      reasonFilter:
          clearReasonFilter ? null : (reasonFilter ?? this.reasonFilter),
    );
  }

  @override
  List<Object?> get props => [
        items,
        nextCursor,
        isLoadingFirstPage,
        isLoadingNextPage,
        failure,
        endReached,
        statusFilter,
        reasonFilter,
      ];
}
