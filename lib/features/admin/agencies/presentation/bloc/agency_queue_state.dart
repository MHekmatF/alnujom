// Phase 19 (spec/019-agencies) — T064
// AgencyQueueState: state for the admin agency verification queue BLoC.
// Mirrors ReportsQueueState from Phase 18 with AgencyStatus filter.
// Constitution IX: zero Supabase imports.
import 'package:equatable/equatable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../agency/domain/entities/agency_status.dart';
import '../../domain/entities/agency_verification_item.dart';

class AgencyQueueState extends Equatable {
  const AgencyQueueState({
    this.items = const <AgencyVerificationItem>[],
    this.nextCursor,
    this.isLoadingFirstPage = false,
    this.isLoadingNextPage = false,
    this.failure,
    this.endReached = false,
    this.statusFilter,
  });

  final List<AgencyVerificationItem> items;

  /// Opaque ISO-8601 cursor for the next page; null on the first page or when
  /// end is reached.
  final String? nextCursor;

  final bool isLoadingFirstPage;
  final bool isLoadingNextPage;
  final Failure? failure;
  final bool endReached;

  /// Active status filter (null = all statuses).
  final AgencyStatus? statusFilter;

  bool get isEmpty =>
      items.isEmpty &&
      !isLoadingFirstPage &&
      !isLoadingNextPage &&
      failure == null;

  AgencyQueueState copyWith({
    List<AgencyVerificationItem>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingFirstPage,
    bool? isLoadingNextPage,
    Failure? failure,
    bool clearFailure = false,
    bool? endReached,
    AgencyStatus? statusFilter,
    bool clearStatusFilter = false,
  }) {
    return AgencyQueueState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      failure: clearFailure ? null : (failure ?? this.failure),
      endReached: endReached ?? this.endReached,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
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
      ];
}
