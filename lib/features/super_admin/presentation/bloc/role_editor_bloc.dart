import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/permission_catalog_entry.dart';
import '../../domain/entities/role_detail.dart';
import '../../domain/entities/role_mutation_result.dart';
import '../../domain/failures.dart';
import '../../domain/usecases/load_permission_catalog.dart';
import '../../domain/usecases/load_role_detail.dart';
import '../../domain/usecases/mutate_role.dart';

sealed class RoleEditorEvent extends Equatable {
  const RoleEditorEvent();

  @override
  List<Object?> get props => [];
}

final class OpenRole extends RoleEditorEvent {
  const OpenRole(this.roleId);

  final String roleId;

  @override
  List<Object?> get props => [roleId];
}

final class UpdateDisplayName extends RoleEditorEvent {
  const UpdateDisplayName(this.locale, this.value);

  final String locale;
  final String value;

  @override
  List<Object?> get props => [locale, value];
}

final class UpdateDescription extends RoleEditorEvent {
  const UpdateDescription(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

final class TogglePermission extends RoleEditorEvent {
  const TogglePermission(this.permKey);

  final String permKey;

  @override
  List<Object?> get props => [permKey];
}

final class SaveRole extends RoleEditorEvent {
  const SaveRole();
}

final class ReloadAfterConflict extends RoleEditorEvent {
  const ReloadAfterConflict();
}

enum RoleSaveConflictReason {
  concurrentEdit,
  superAdminImmutable,
  systemRoleProtected,
}

sealed class RoleEditorState extends Equatable {
  const RoleEditorState();

  @override
  List<Object?> get props => [];
}

final class RoleEditorInitial extends RoleEditorState {
  const RoleEditorInitial();
}

final class RoleEditorLoading extends RoleEditorState {
  const RoleEditorLoading();
}

final class RoleEditorEditing extends RoleEditorState {
  const RoleEditorEditing({
    required this.original,
    required this.current,
    required this.catalog,
    required this.expectedUpdatedAt,
    required this.dirty,
    required this.isSuperAdminRow,
    required this.saving,
  });

  final RoleDetail original;
  final RoleDetail current;
  final List<PermissionCatalogEntry> catalog;
  final DateTime expectedUpdatedAt;
  final bool dirty;
  final bool isSuperAdminRow;
  final bool saving;

  bool get permissionSetChanged =>
      !_sameStringSet(original.permissionKeys, current.permissionKeys);

  RoleEditorEditing copyWith({RoleDetail? current, bool? saving}) {
    final nextCurrent = current ?? this.current;
    return RoleEditorEditing(
      original: original,
      current: nextCurrent,
      catalog: catalog,
      expectedUpdatedAt: expectedUpdatedAt,
      dirty: nextCurrent != original,
      isSuperAdminRow: isSuperAdminRow,
      saving: saving ?? this.saving,
    );
  }

  @override
  List<Object?> get props => [
    original,
    current,
    catalog,
    expectedUpdatedAt,
    dirty,
    isSuperAdminRow,
    saving,
  ];
}

final class RoleEditorSaveSucceeded extends RoleEditorState {
  const RoleEditorSaveSucceeded(this.result);

  final RoleMutationResult result;

  @override
  List<Object?> get props => [result];
}

final class RoleEditorSaveConflict extends RoleEditorState {
  const RoleEditorSaveConflict(this.reason);

  final RoleSaveConflictReason reason;

  @override
  List<Object?> get props => [reason];
}

final class RoleEditorSaveError extends RoleEditorState {
  const RoleEditorSaveError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class RoleEditorLoadFailure extends RoleEditorState {
  const RoleEditorLoadFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

@injectable
class RoleEditorBloc extends Bloc<RoleEditorEvent, RoleEditorState> {
  RoleEditorBloc(
    this._loadRoleDetail,
    this._loadPermissionCatalog,
    this._mutateRole,
  ) : super(const RoleEditorInitial()) {
    on<OpenRole>(_openRole);
    on<UpdateDisplayName>(_updateDisplayName);
    on<UpdateDescription>(_updateDescription);
    on<TogglePermission>(_togglePermission);
    on<SaveRole>(_save);
    on<ReloadAfterConflict>(_reloadAfterConflict);
  }

  final LoadRoleDetail _loadRoleDetail;
  final LoadPermissionCatalog _loadPermissionCatalog;
  final MutateRole _mutateRole;
  String? _currentRoleId;

  Future<void> _openRole(OpenRole event, Emitter<RoleEditorState> emit) async {
    _currentRoleId = event.roleId;
    emit(const RoleEditorLoading());
    try {
      final role = await _loadRoleDetail(event.roleId);
      final catalog = await _loadPermissionCatalog();
      emit(
        RoleEditorEditing(
          original: role,
          current: role,
          catalog: catalog,
          expectedUpdatedAt: role.updatedAt,
          dirty: false,
          isSuperAdminRow: role.roleKey == 'super_admin',
          saving: false,
        ),
      );
    } on Failure catch (failure) {
      emit(RoleEditorLoadFailure(failure));
    } on Object catch (error, stackTrace) {
      emit(
        RoleEditorLoadFailure(
          BackendFailure(
            error.toString(),
            cause: error,
            stackTrace: stackTrace,
          ),
        ),
      );
    }
  }

  void _updateDisplayName(
    UpdateDisplayName event,
    Emitter<RoleEditorState> emit,
  ) {
    final editing = state;
    if (editing is! RoleEditorEditing) return;
    final displayName = Map<String, String>.from(editing.current.displayName);
    displayName[event.locale] = event.value;
    emit(
      editing.copyWith(
        current: editing.current.copyWith(displayName: displayName),
      ),
    );
  }

  void _updateDescription(
    UpdateDescription event,
    Emitter<RoleEditorState> emit,
  ) {
    final editing = state;
    if (editing is! RoleEditorEditing) return;
    emit(
      editing.copyWith(
        current: editing.current.copyWith(description: event.value),
      ),
    );
  }

  void _togglePermission(
    TogglePermission event,
    Emitter<RoleEditorState> emit,
  ) {
    final editing = state;
    if (editing is! RoleEditorEditing || editing.isSuperAdminRow) return;
    final permissionKeys = editing.current.permissionKeys.toSet();
    if (!permissionKeys.add(event.permKey)) {
      permissionKeys.remove(event.permKey);
    }
    emit(
      editing.copyWith(
        current: editing.current.copyWith(
          permissionKeys: permissionKeys.toList()..sort(),
        ),
      ),
    );
  }

  Future<void> _save(SaveRole event, Emitter<RoleEditorState> emit) async {
    final editing = state;
    if (editing is! RoleEditorEditing || !editing.dirty || editing.saving) {
      return;
    }
    emit(editing.copyWith(saving: true));
    try {
      final result = await _mutateRole(
        UpdateRoleParams(
          roleId: editing.original.roleId,
          displayName: editing.current.displayName,
          description: editing.current.description,
          permissionKeys: editing.current.permissionKeys,
          expectedUpdatedAt: editing.expectedUpdatedAt,
        ),
      );
      emit(RoleEditorSaveSucceeded(result));
    } on RoleEditConflictFailure {
      emit(const RoleEditorSaveConflict(RoleSaveConflictReason.concurrentEdit));
      emit(editing.copyWith(saving: false));
    } on SuperAdminPermissionsImmutableFailure {
      emit(
        const RoleEditorSaveConflict(
          RoleSaveConflictReason.superAdminImmutable,
        ),
      );
      emit(editing.copyWith(saving: false));
    } on SystemRoleImmutableFailure {
      emit(
        const RoleEditorSaveConflict(
          RoleSaveConflictReason.systemRoleProtected,
        ),
      );
      emit(editing.copyWith(saving: false));
    } on Failure catch (failure) {
      emit(RoleEditorSaveError(failure));
      emit(editing.copyWith(saving: false));
    }
  }

  void _reloadAfterConflict(
    ReloadAfterConflict event,
    Emitter<RoleEditorState> emit,
  ) {
    final roleId = _currentRoleId;
    if (roleId != null) add(OpenRole(roleId));
  }
}

bool _sameStringSet(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final bSet = b.toSet();
  return a.every(bSet.contains);
}
