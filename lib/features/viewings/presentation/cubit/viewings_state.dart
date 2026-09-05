part of 'viewings_cubit.dart';

enum ViewingsStatus { initial, loading, list, error }

final class ViewingsState extends Equatable {
  const ViewingsState._({
    required this.status,
    this.viewings = const [],
    this.hasMore = false,
    this.loadingMore = false,
  });

  const ViewingsState.initial() : this._(status: ViewingsStatus.initial);

  const ViewingsState.loading() : this._(status: ViewingsStatus.loading);

  const ViewingsState.list(
    List<Viewing> viewings, {
    bool hasMore = false,
    bool loadingMore = false,
  }) : this._(
         status: ViewingsStatus.list,
         viewings: viewings,
         hasMore: hasMore,
         loadingMore: loadingMore,
       );

  const ViewingsState.error() : this._(status: ViewingsStatus.error);

  final ViewingsStatus status;
  final List<Viewing> viewings;

  /// Plan A36 — another page may exist after the last row shown.
  final bool hasMore;
  final bool loadingMore;

  @override
  List<Object?> get props => [status, viewings, hasMore, loadingMore];
}
