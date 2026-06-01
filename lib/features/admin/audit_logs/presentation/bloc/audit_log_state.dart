// Phase 20 (spec/020-admin-dashboard) — T023
// AuditLogState: paged loading/loaded/error state for the read-only
// audit-log viewer. Constitution IX: zero Supabase imports.
import 'package:equatable/equatable.dart';

import '../../../../../core/errors/failure.dart';
import '../../domain/entities/audit_log_entry.dart';

class AuditLogState extends Equatable {
  const AuditLogState({
    this.items = const <AuditLogEntry>[],
    this.nextCursor,
    this.isLoadingFirstPage = false,
    this.isLoadingNextPage = false,
    this.failure,
    this.endReached = false,
  });

  final List<AuditLogEntry> items;

  /// Opaque ISO-8601 cursor for the next page; null on the first page or
  /// when the end is reached.
  final String? nextCursor;

  final bool isLoadingFirstPage;
  final bool isLoadingNextPage;
  final Failure? failure;
  final bool endReached;

  bool get isEmpty =>
      items.isEmpty &&
      !isLoadingFirstPage &&
      !isLoadingNextPage &&
      failure == null;

  AuditLogState copyWith({
    List<AuditLogEntry>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingFirstPage,
    bool? isLoadingNextPage,
    Failure? failure,
    bool clearFailure = false,
    bool? endReached,
  }) {
    return AuditLogState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      failure: clearFailure ? null : (failure ?? this.failure),
      endReached: endReached ?? this.endReached,
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
  ];
}
