import 'package:flutter/widgets.dart' show Locale;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../shared/domain/entities/profile.dart';
import '../entities/private_contact_methods.dart';

/// Bundle of the three Vault-backed PII fields (FR-005 / FR-006).
class PiiBundle {
  const PiiBundle({this.legalName, this.nationalId, this.privateContactMethods});

  final String? legalName;
  final String? nationalId;
  final PrivateContactMethods? privateContactMethods;
}

/// Profile repository contract (Phase 5 FR-012, contracts/profile-repository.md).
///
/// Constitution IX: no Supabase types in this file.
abstract class ProfileRepository {
  /// Snapshot read of the calling user's profile.
  Future<Result<Profile>> getCurrentProfile();

  /// Stream of profile changes (refresh-driven; Phase 22 swaps to Realtime).
  Stream<Profile> get currentProfileStream;

  /// Force a refresh — re-reads the row and emits on [currentProfileStream].
  /// Used by AuthBloc on app foreground to detect out-of-band suspension (R-21).
  Future<Result<Profile>> refresh();

  /// Update non-status, non-admin, non-PII fields on the calling user's profile.
  ///
  /// `phone` is included to support the registration flow (FR-002) where the
  /// auto-provision trigger leaves it NULL and the client fills it in. The
  /// profile-edit page in Phase 5 (US2) renders phone read-only and MUST NOT
  /// include it in the update payload — the UNIQUE constraint at the DB level
  /// is the second line of defense.
  Future<Result<Profile>> updateProfile({
    String? fullName,
    String? username,
    String? phone,
    String? email,
    String? avatarUrl,
  });

  /// Push the device-side locale into `user_preferences.locale`.
  /// Used by registration (R-11 first-sign-in handoff) and the in-app picker.
  Future<Result<void>> updateLocale(Locale locale);

  /// Read the three Vault-stored PII fields for the calling user.
  Future<Result<PiiBundle>> loadPii();

  /// Write Vault-stored PII (TEXT-typed fields).
  Future<Result<void>> updateLegalName(String legalName);
  Future<Result<void>> updateNationalId(String nationalId);

  /// Write Vault-stored private_contact_methods (JSON-typed; keys allowlisted).
  Future<Result<void>> updatePrivateContactMethods(
    PrivateContactMethods methods,
  );

  /// Release the internal broadcast stream controller.
  Future<void> dispose();
}

// ───────────────────────────────────────────────────────────────────────────
// Profile-feature-specific failures
// ───────────────────────────────────────────────────────────────────────────

sealed class ProfileFailure extends Failure {
  const ProfileFailure(super.message, {super.cause, super.stackTrace});
}

final class UsernameTaken extends ProfileFailure {
  const UsernameTaken({super.cause, super.stackTrace}) : super('username_taken');
}

final class InvalidFullName extends ProfileFailure {
  const InvalidFullName({super.cause, super.stackTrace})
    : super('invalid_full_name');
}

final class InvalidUsername extends ProfileFailure {
  const InvalidUsername({super.cause, super.stackTrace})
    : super('invalid_username');
}

final class InvalidEmail extends ProfileFailure {
  const InvalidEmail({super.cause, super.stackTrace}) : super('invalid_email');
}

final class InvalidAvatarUrl extends ProfileFailure {
  const InvalidAvatarUrl({super.cause, super.stackTrace})
    : super('invalid_avatar_url');
}

final class NotAuthenticated extends ProfileFailure {
  const NotAuthenticated({super.cause, super.stackTrace})
    : super('not_authenticated');
}

final class UnknownProfileError extends ProfileFailure {
  const UnknownProfileError(super.message, {super.cause, super.stackTrace});
}
