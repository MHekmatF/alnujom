part of 'viewings_cubit.dart';

enum ViewingsStatus { initial, loading, list, error }

final class ViewingsState extends Equatable {
  const ViewingsState._({required this.status, this.viewings = const []});

  const ViewingsState.initial() : this._(status: ViewingsStatus.initial);

  const ViewingsState.loading() : this._(status: ViewingsStatus.loading);

  const ViewingsState.list(List<Viewing> viewings)
    : this._(status: ViewingsStatus.list, viewings: viewings);

  const ViewingsState.error() : this._(status: ViewingsStatus.error);

  final ViewingsStatus status;
  final List<Viewing> viewings;

  @override
  List<Object?> get props => [status, viewings];
}
