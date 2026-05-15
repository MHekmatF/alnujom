import 'package:equatable/equatable.dart';

import '../../../../shared/domain/entities/profile.dart';
import '../../domain/entities/assigned_role.dart';
import '../../domain/repositories/profile_repository.dart';

enum ProfileStatus { initial, loading, loaded, editing, saving, saveFailure }

enum PiiStatus { idle, loading, loaded, saving, saveFailure }

/// Unified state for [ProfileCubit].
///
/// Public-profile state ([status], [profile], [draft], [failure]) and PII
/// state ([piiStatus], [pii], [piiFailure]) are decoupled: the profile page
/// does not trigger PII loading; the private page drives PII operations
/// independently.
class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.draft,
    this.failure,
    this.piiStatus = PiiStatus.idle,
    this.pii,
    this.piiFailure,
    this.roles = const [],
  });

  final ProfileStatus status;
  final Profile? profile;

  /// Non-null while editing ([ProfileStatus.editing]).
  final Profile? draft;

  final ProfileFailure? failure;

  final PiiStatus piiStatus;
  final PiiBundle? pii;
  final ProfileFailure? piiFailure;

  /// The signed-in user's assigned roles (empty until [ProfileCubit.loadRoles] completes).
  final List<AssignedRole> roles;

  bool get isEditing => draft != null;

  // ── convenience transition helpers ──────────────────────────────────────

  ProfileState profileLoading() => ProfileState(
    status: ProfileStatus.loading,
    piiStatus: piiStatus,
    pii: pii,
    roles: roles,
  );

  ProfileState profileLoaded(Profile p) => ProfileState(
    status: ProfileStatus.loaded,
    profile: p,
    piiStatus: piiStatus,
    pii: pii,
    roles: roles,
  );

  ProfileState profileEditing(Profile p) => ProfileState(
    status: ProfileStatus.editing,
    profile: profile,
    draft: p,
    piiStatus: piiStatus,
    pii: pii,
    roles: roles,
  );

  ProfileState profileSaving() => ProfileState(
    status: ProfileStatus.saving,
    profile: profile,
    draft: draft,
    piiStatus: piiStatus,
    pii: pii,
    roles: roles,
  );

  ProfileState profileSaveFailure(ProfileFailure f) => ProfileState(
    status: ProfileStatus.saveFailure,
    profile: profile,
    draft: draft,
    failure: f,
    piiStatus: piiStatus,
    pii: pii,
    roles: roles,
  );

  ProfileState piiLoading() => ProfileState(
    status: status,
    profile: profile,
    draft: draft,
    piiStatus: PiiStatus.loading,
    roles: roles,
  );

  ProfileState piiLoaded(PiiBundle bundle) => ProfileState(
    status: status,
    profile: profile,
    draft: draft,
    piiStatus: PiiStatus.loaded,
    pii: bundle,
    roles: roles,
  );

  ProfileState piiSaving() => ProfileState(
    status: status,
    profile: profile,
    draft: draft,
    piiStatus: PiiStatus.saving,
    pii: pii,
    roles: roles,
  );

  ProfileState piiSaveFailure(ProfileFailure f) => ProfileState(
    status: status,
    profile: profile,
    draft: draft,
    piiStatus: PiiStatus.saveFailure,
    pii: pii,
    piiFailure: f,
    roles: roles,
  );

  ProfileState withRoles(List<AssignedRole> updatedRoles) => ProfileState(
    status: status,
    profile: profile,
    draft: draft,
    failure: failure,
    piiStatus: piiStatus,
    pii: pii,
    piiFailure: piiFailure,
    roles: updatedRoles,
  );

  @override
  List<Object?> get props => [
    status,
    profile,
    draft,
    failure,
    piiStatus,
    pii,
    piiFailure,
    roles,
  ];
}
