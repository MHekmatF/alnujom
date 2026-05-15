import 'package:equatable/equatable.dart';

import '../../../../../core/errors/failure.dart';
import '../../domain/entities/account_approval_request.dart';

sealed class AccountApprovalsState extends Equatable {
  const AccountApprovalsState();
}

final class AccountApprovalsInitial extends AccountApprovalsState {
  const AccountApprovalsInitial();

  @override
  List<Object?> get props => [];
}

final class AccountApprovalsLoading extends AccountApprovalsState {
  const AccountApprovalsLoading();

  @override
  List<Object?> get props => [];
}

final class AccountApprovalsLoaded extends AccountApprovalsState {
  const AccountApprovalsLoaded(this.requests);

  final List<AccountApprovalRequest> requests;

  @override
  List<Object?> get props => [requests];
}

final class AccountApprovalsError extends AccountApprovalsState {
  const AccountApprovalsError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Emitted while an approve/reject mutation is in flight.
final class AccountApprovalsMutating extends AccountApprovalsState {
  const AccountApprovalsMutating(this.requests);

  final List<AccountApprovalRequest> requests;

  @override
  List<Object?> get props => [requests];
}
