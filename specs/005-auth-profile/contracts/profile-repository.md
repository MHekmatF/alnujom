# Contract: `ProfileRepository` Domain Interface

**Owner**: Phase 5 (`lib/features/profile/domain/repositories/profile_repository.dart`).
**Implementation**: `lib/features/profile/data/repositories/profile_repository_impl.dart`.
**Consumers**: `ProfileCubit`, `AuthBloc` (subscribes to `currentProfileStream` for the post-login destination decision), the registration use case (calls `updateProfile` + `updateLocale` after `signUp`), the admin queue's `ApproveAccount` / `RejectAccount` use cases (read profiles to populate the queue's denormalized snippet via the data source's join, not via this repository).
**Stability**: Stable across Phase 5 and Phase 6. Phase 7 may add admin-side methods (e.g., `getProfilesForAdmin()`) without touching the existing methods.

---

## Purpose

The single domain-layer entry point to profile reads, profile writes, and Vault-PII reads/writes. The interface is provider-agnostic (Constitution IX); the impl translates to Postgrest queries + RPCs to the SECURITY DEFINER PII helpers.

> **Note on `Either<L, R>`**: every `Either<ProfileFailure, T>` signature in this contract is documented as illustrative. The actual implementation uses the project's existing `Result<T>` / `FailureResult<T>` from `lib/core/errors/` — see research R-22. `ProfileFailure` extends Phase 4's `Failure` base class (which Phase 5 loosened from `sealed` to `abstract`). The contract shape is unchanged; only the carrier type differs.

## Interface

```dart
// lib/features/profile/domain/repositories/profile_repository.dart
abstract class ProfileRepository {
  /// Snapshot read of the calling user's profile.
  /// Reads include the new `is_admin` field (FR-007).
  Future<Either<ProfileFailure, Profile>> getCurrentProfile();

  /// Stream of profile changes — emits whenever the underlying row mutates AND
  /// whenever the bloc explicitly asks for a refresh (foreground resume per R-21).
  /// Backed by a manual refresh trigger; Phase 22 swaps to a Realtime subscription.
  Stream<Profile> get currentProfileStream;

  /// Updates non-status, non-admin, non-PII fields on the calling user's profile.
  /// Username uniqueness is enforced server-side; the impl maps Postgres '23505'
  /// on profiles_username_key to Left(UsernameTaken).
  ///
  /// **The `phone` parameter is for the registration flow only** (FR-002 — Phase 4's
  /// auto-provision trigger creates the profile with a NULL phone, and the registration
  /// use case writes the E.164 phone here in the same call as `fullName` + `email`).
  /// The profile-edit page (US2 / T078) MUST NOT pass `phone` — phone is read-only
  /// post-registration. The DB-level `UNIQUE(phone)` constraint is the second line of
  /// defense; a `'23505'` collision on `profiles_phone_key` maps to a typed phone-uniqueness
  /// failure (mirrors `AccountAlreadyExists` on the auth side).
  Future<Either<ProfileFailure, Profile>> updateProfile({
    String? fullName,        // omit to keep current; pass empty/null to clear (validation rejects)
    String? username,
    PhoneNumber? phone,      // registration flow only; profile-edit page MUST omit this
    String? email,
    String? avatarUrl,
  });

  /// Pushes a locale value into user_preferences for the calling user.
  /// Used by the registration flow (R-11 first-sign-in handoff) and by the
  /// in-app locale picker.
  Future<Either<ProfileFailure, Unit>> updateLocale(Locale locale);

  /// Reads the three Vault-stored PII fields for the calling user.
  /// Returns a typed bundle. Each field is null if the user has not stored a value.
  Future<Either<ProfileFailure, PiiBundle>> loadPii();

  /// Writes a single Vault-stored PII field. The impl dispatches to the right
  /// SECURITY DEFINER RPC based on `field` (`legal_name` / `national_id` →
  /// app_vault_set_secret_for_self; `private_contact_methods` → app_vault_set_private_contact_methods_for_self).
  Future<Either<ProfileFailure, Unit>> updateLegalName(String legalName);
  Future<Either<ProfileFailure, Unit>> updateNationalId(String nationalId);
  Future<Either<ProfileFailure, Unit>> updatePrivateContactMethods(PrivateContactMethods methods);
}

class PiiBundle {
  final String? legalName;
  final String? nationalId;
  final PrivateContactMethods? privateContactMethods;
  const PiiBundle({this.legalName, this.nationalId, this.privateContactMethods});
}

sealed class ProfileFailure { ... }
class UsernameTaken extends ProfileFailure { ... }
class InvalidFullName extends ProfileFailure { ... }
class InvalidUsername extends ProfileFailure { ... }
class InvalidEmail extends ProfileFailure { ... }
class InvalidAvatarUrl extends ProfileFailure { ... }
class InvalidPhoneInContactMethods extends ProfileFailure { ... }
class InvalidContactChannel extends ProfileFailure { ... }
class NotAuthenticated extends ProfileFailure { ... }
class NetworkErrorProfile extends ProfileFailure { ... }
class UnknownProfileError extends ProfileFailure { final String message; ... }
```

## Behavior contract

### `getCurrentProfile`

```dart
final row = await supabase
  .from('profiles')
  .select('*')
  .eq('user_id', auth.currentUser!.id)
  .single();
return Right(profileFromRow(row));
```

Maps the row to the domain `Profile` entity including the new `is_admin` field. RLS guarantees only the user's own row is returned.

### `updateProfile`

1. Domain-layer validation per R-17 (rules table). Failures return Left(...) without hitting the network.
2. `supabase.from('profiles').update({fullName, username, email, avatarUrl, 'updated_at': 'now()'}).eq('user_id', uid).select()`.
3. Map Postgres errors:
   - `'23505'` on `profiles_username_key` → Left(`UsernameTaken`).
   - `'42501'` (from the `enforce_profile_status_admin_only` trigger) — should not happen in this code path because the update payload excludes status/admin fields, but if it does occur (e.g., a buggy caller passes them), the data layer maps to `UnknownProfileError` with a developer-message.
4. Return Right(refreshed Profile).

### `updateLocale`

```dart
await supabase
  .from('user_preferences')
  .update({'locale': locale.toString(), 'updated_at': 'now()'})
  .eq('user_id', uid);
```

Per FR-018: also writes through to `flutter_secure_storage` via Phase 1's wrapper so the offline cache stays coherent. Both writes happen in the same use-case call (`UpdateProfile.updateLocale` orchestrates).

### `loadPii`

Three parallel RPC calls (the three field reads are independent):

```dart
final results = await Future.wait([
  supabase.rpc('app_vault_secret_for_self', params: {'field_name': 'legal_name'}).single(),
  supabase.rpc('app_vault_secret_for_self', params: {'field_name': 'national_id'}).single(),
  supabase.rpc('app_vault_secret_for_self', params: {'field_name': 'private_contact_methods'}).single(),
]);

final legal = results[0] as String?;
final nat = results[1] as String?;
final methodsRaw = results[2] as String?;
final methods = methodsRaw != null
    ? PrivateContactMethods.fromJson(jsonDecode(methodsRaw))
    : null;
return Right(PiiBundle(legalName: legal, nationalId: nat, privateContactMethods: methods));
```

### `updateLegalName` / `updateNationalId`

```dart
await supabase.rpc('app_vault_set_secret_for_self',
  params: {'field_name': 'legal_name', 'p_value': legalName});
return Right(Unit());
```

Domain validation is light here — Phase 5 does not enforce a length or format on `legal_name` / `national_id` (the user's input is sovereign for the v1 use case). Future phases (Phase 19 agency verification) may add stricter validation as part of their own contract.

### `updatePrivateContactMethods`

1. Domain-layer validation: every key in `methods.channels` must be a known `ContactChannel`; the `secondaryPhone` value must parse as `PhoneNumber` (already enforced by the entity's constructor).
2. `supabase.rpc('app_vault_set_private_contact_methods_for_self', params: {'p_methods': methods.toJson()})`.
3. The SQL function additionally validates the keys against its own allowlist as defense-in-depth (R-13).

## Invariants

- The `domain/` subfolder of `lib/features/profile/` imports nothing from `package:supabase_flutter`.
- `Profile` always carries the `is_admin` field after Phase 5 ships; before-Phase-5 code paths that pass `Profile()` without `isAdmin` get the default `false`.
- `loadPii` is the ONLY way the presentation layer reads PII; the data source does NOT expose a path that returns the raw `pii.<uuid>.<field>` secret name to callers.
- `updatePrivateContactMethods` is the ONLY way to write contact methods; the TEXT setters reject `field_name = 'private_contact_methods'` to steer callers (R-13).

## Verification

The repository is exercised end-to-end by `quickstart.md` — there are no unit tests per the durable no-new-tests rule. Manual verification: register a user, update profile fields, observe the row updates; save PII fields, observe `vault.secrets` rows.
