import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../shared/domain/entities/profile.dart';
import '../../domain/entities/private_contact_methods.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/load_assigned_roles.dart';
import '../../domain/usecases/load_pii.dart';
import '../../domain/usecases/load_profile.dart';
import '../../domain/usecases/update_pii.dart';
import '../../domain/usecases/update_profile.dart';
import 'profile_state.dart';

@injectable
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(
    this._load,
    this._update,
    this._loadPii,
    this._updatePii,
    this._loadAssignedRoles,
  ) : super(const ProfileState());

  final LoadProfile _load;
  final UpdateProfile _update;
  final LoadPii _loadPii;
  final UpdatePii _updatePii;
  final LoadAssignedRoles _loadAssignedRoles;

  // ── Public profile ───────────────────────────────────────────────────────

  Future<void> load() async {
    emit(state.profileLoading());
    final result = await _load();
    if (result is Success<Profile>) {
      emit(state.profileLoaded(result.value));
    } else {
      final f = (result as FailureResult<Profile>).failure;
      emit(
        state.profileSaveFailure(
          f is ProfileFailure ? f : UnknownProfileError(f.message),
        ),
      );
    }
  }

  void startEdit() {
    if (state.profile == null) return;
    emit(state.profileEditing(state.profile!));
  }

  void updateDraft({
    String? fullName,
    String? username,
    String? email,
    String? avatarUrl,
  }) {
    if (!state.isEditing) return;
    emit(
      state.profileEditing(
        state.draft!.copyWith(
          fullName: fullName,
          username: username,
          email: email,
          avatarUrl: avatarUrl,
        ),
      ),
    );
  }

  Future<void> save() async {
    if (!state.isEditing) return;
    final d = state.draft!;
    emit(state.profileSaving());
    final result = await _update(
      fullName: d.fullName,
      username: d.username,
      email: d.email,
      avatarUrl: d.avatarUrl,
    );
    if (result is Success<Profile>) {
      emit(state.profileLoaded(result.value));
    } else {
      final f = (result as FailureResult<Profile>).failure;
      emit(
        state.profileSaveFailure(
          f is ProfileFailure ? f : UnknownProfileError(f.message),
        ),
      );
    }
  }

  void cancelEdit() {
    if (!state.isEditing) return;
    emit(state.profileLoaded(state.profile!));
  }

  // ── Assigned roles ───────────────────────────────────────────────────────

  Future<void> loadRoles(String localeCode) async {
    final roles = await _loadAssignedRoles(localeCode);
    emit(state.withRoles(roles));
  }

  // ── PII ──────────────────────────────────────────────────────────────────

  Future<void> loadPii() async {
    emit(state.piiLoading());
    final result = await _loadPii();
    if (result is Success<PiiBundle>) {
      emit(state.piiLoaded(result.value));
    } else {
      final f = (result as FailureResult<PiiBundle>).failure;
      emit(
        state.piiSaveFailure(
          f is ProfileFailure ? f : UnknownProfileError(f.message),
        ),
      );
    }
  }

  Future<void> saveLegalName(String name) async {
    final pii = state.pii;
    if (pii == null) return;
    emit(state.piiSaving());
    final result = await _updatePii.saveLegalName(name);
    if (result is Success<void>) {
      emit(
        state.piiLoaded(
          PiiBundle(
            legalName: name,
            nationalId: pii.nationalId,
            privateContactMethods: pii.privateContactMethods,
          ),
        ),
      );
    } else {
      final f = (result as FailureResult<void>).failure;
      emit(
        state.piiSaveFailure(
          f is ProfileFailure ? f : UnknownProfileError(f.message),
        ),
      );
    }
  }

  Future<void> saveNationalId(String id) async {
    final pii = state.pii;
    if (pii == null) return;
    emit(state.piiSaving());
    final result = await _updatePii.saveNationalId(id);
    if (result is Success<void>) {
      emit(
        state.piiLoaded(
          PiiBundle(
            legalName: pii.legalName,
            nationalId: id,
            privateContactMethods: pii.privateContactMethods,
          ),
        ),
      );
    } else {
      final f = (result as FailureResult<void>).failure;
      emit(
        state.piiSaveFailure(
          f is ProfileFailure ? f : UnknownProfileError(f.message),
        ),
      );
    }
  }

  Future<void> saveContactMethods(PrivateContactMethods methods) async {
    final pii = state.pii;
    if (pii == null) return;
    emit(state.piiSaving());
    final result = await _updatePii.saveContactMethods(methods);
    if (result is Success<void>) {
      emit(
        state.piiLoaded(
          PiiBundle(
            legalName: pii.legalName,
            nationalId: pii.nationalId,
            privateContactMethods: methods,
          ),
        ),
      );
    } else {
      final f = (result as FailureResult<void>).failure;
      emit(
        state.piiSaveFailure(
          f is ProfileFailure ? f : UnknownProfileError(f.message),
        ),
      );
    }
  }
}
