import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/role_with_counts.dart';
import '../../domain/failures.dart';
import '../../domain/usecases/list_roles.dart';

sealed class RolesListEvent extends Equatable {
  const RolesListEvent();

  @override
  List<Object?> get props => [];
}

final class LoadRoles extends RolesListEvent {
  const LoadRoles();
}

final class RefreshRoles extends RolesListEvent {
  const RefreshRoles();
}

sealed class RolesListState extends Equatable {
  const RolesListState();

  @override
  List<Object?> get props => [];
}

final class RolesListInitial extends RolesListState {
  const RolesListInitial();
}

final class RolesListLoading extends RolesListState {
  const RolesListLoading();
}

final class RolesListLoaded extends RolesListState {
  const RolesListLoaded(this.roles);

  final List<RoleWithCounts> roles;

  @override
  List<Object?> get props => [roles];
}

final class RolesListLoadFailure extends RolesListState {
  const RolesListLoadFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

@injectable
class RolesListBloc extends Bloc<RolesListEvent, RolesListState> {
  RolesListBloc(this._listRoles) : super(const RolesListInitial()) {
    on<LoadRoles>(_load);
    on<RefreshRoles>(_load);
  }

  final ListRoles _listRoles;

  Future<void> _load(RolesListEvent event, Emitter<RolesListState> emit) async {
    emit(const RolesListLoading());
    try {
      emit(RolesListLoaded(await _listRoles()));
    } on Failure catch (failure) {
      emit(RolesListLoadFailure(failure));
    } on Object catch (error, stackTrace) {
      emit(
        RolesListLoadFailure(
          BackendFailure(
            error.toString(),
            cause: error,
            stackTrace: stackTrace,
          ),
        ),
      );
    }
  }
}
