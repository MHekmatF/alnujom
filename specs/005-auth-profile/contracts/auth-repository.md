# Contract: `AuthRepository` Domain Interface

**Owner**: Phase 5 (`lib/features/auth/domain/repositories/auth_repository.dart`).
**Implementation**: `lib/features/auth/data/repositories/auth_repository_impl.dart` (the only Phase 5 file in the auth feature that imports `package:supabase_flutter`, alongside the data sources it composes).
**Consumers**: `AuthBloc` (`lib/features/auth/presentation/bloc/`), the registration / login / logout / reset-password use cases, the go_router redirect helper.
**Stability**: Stable across Phase 5 and Phase 6. Phase 6 swaps the underlying admin predicate but does NOT change this interface. A future custom-backend swap (Constitution IX) replaces the implementation, not the interface.

---

## Purpose

The single domain-layer entry point to authentication primitives. The implementation hides the synthetic-email construction (`<E.164>@alnujom.local`), the Supabase Auth call sequence (signUp / signInWithPassword / signOut / the `request_password_reset` Edge Function), and the auth-state stream subscription from Phase 4's `SupabaseClientWrapper`.

## Interface

```dart
// lib/features/auth/domain/repositories/auth_repository.dart
abstract class AuthRepository {
  /// Domain-shaped session stream. Emits null when signed out.
  Stream<Session?> get sessionStream;

  /// Snapshot read of the current session (null if signed out).
  Session? get currentSession;

  /// Register: creates auth.users + (via Phase 4 trigger) profiles + user_preferences
  /// + (via Phase 5 trigger) account_approval_requests. Then writes the registration form's
  /// full_name / phone / email AND the device-side locale onto the new profile (R-11).
  ///
  /// Returns Right(Session) on success, Left(AuthFailure) on validated failure.
  Future<Either<AuthFailure, Session>> register({
    required PhoneNumber phone,
    required String password,
    required String? fullName,
    required String? optionalRealEmail,
    required Locale deviceLocale,
  });

  /// Login with phone + password. Repository derives the synthetic email internally.
  Future<Either<AuthFailure, Session>> login({
    required PhoneNumber phone,
    required String password,
  });

  /// Sign out. Clears the local session token.
  Future<void> logout();

  /// Reset-password flow. ALWAYS resolves to Right(Unit) regardless of whether
  /// the phone is known or has an email on file. The Edge Function `request_password_reset`
  /// implements the account-enumeration-resistance guarantee server-side (FR-017).
  ///
  /// Left(AuthFailure) only on transport-level errors (no network, etc.).
  Future<Either<AuthFailure, Unit>> requestPasswordReset({
    required PhoneNumber phone,
  });
}
```

(`Either<L, R>` and `Unit` above are documented as illustrative of the shape. **The actual implementation uses the project's existing `Result<T>` / `FailureResult<T>` from `lib/core/errors/` instead** — see research R-22 for the decision and rationale. Wherever this contract shows `Either<AuthFailure, T>`, read it as `Result<T>` carrying the typed `AuthFailure` via `FailureResult<T>`. Phase 4's `Failure` base class was loosened from `sealed` to `abstract` so `AuthFailure extends Failure` slots in cleanly — the only Phase 4 file edit Phase 5 makes, captured in research R-22.)

## Behavior contract

### `register`

1. Construct `syntheticEmail = '<phone.e164>@alnujom.local'` via `lib/features/auth/data/internal/synthetic_email.dart`.
2. `supabase.auth.signUp(email: syntheticEmail, password: password)`.
   - Failure mapping:
     - `AuthApiException` with `code == 'user_already_exists'` (or status 422 + matching message) → Left(`AccountAlreadyExists`).
     - `AuthApiException` with `code == 'weak_password'` → Left(`PasswordTooShort`) (defensive — the app validator should catch this first).
     - Network / timeout → Left(`NetworkError`).
     - Other → Left(`UnknownAuthError`).
3. Wait for the auto-provision trigger to fire (Phase 4 R-07 atomic) — the resulting `auth.users` insert produces the `profiles` row before `signUp` returns.
4. `UPDATE profiles SET full_name=$1, phone=$2, email=$3, updated_at=now() WHERE user_id=$4` via Postgrest.
   - The `phone` write may collide with another concurrent registration's phone (impossible in practice given step 2's synthetic-email uniqueness check, but defensible) — `'23505'` on `profiles_phone_key` → Left(`AccountAlreadyExists`).
5. `UPDATE user_preferences SET locale=$1 WHERE user_id=$2` via Postgrest with `deviceLocale` (R-11 locale handoff).
6. Return Right(the new `Session`).

### `login`

1. Construct synthetic email as above.
2. `supabase.auth.signInWithPassword(email: syntheticEmail, password: password)`.
   - Failure mapping:
     - `AuthApiException` with `code == 'invalid_credentials'` (or status 400/401 + matching message) → Left(`InvalidPhoneOrPassword`).
     - Network / timeout → Left(`NetworkError`).
     - Other → Left(`UnknownAuthError`).
3. **Read the user's `user_preferences.locale`** and push it into both `flutter_secure_storage` and the `LocaleCubit` (R-11 server-wins-on-subsequent-sign-in).
4. Return Right(the new `Session`).

### `logout`

1. `supabase.auth.signOut()`.
2. The `SupabaseClientWrapper.authStateChanges()` subscription emits `signedOut` → `sessionStream` emits `null` → bloc transitions to `Unauthenticated`.
3. Local secure_storage's auth-related keys (refresh tokens) are cleared by Supabase Auth's own machinery; the locale key is preserved (it is a UI preference, not a credential).
4. Returns void; no failure path is exposed (a sign-out failure is logged but not user-actionable).

### `requestPasswordReset`

1. Invoke the Edge Function via `supabase.functions.invoke('request_password_reset', body: {phone: phone.e164})`.
2. Map the response:
   - 200 + `{ok: true}` → Right(Unit). The UI displays the generic "if an account exists for this phone, a reset link has been sent" copy regardless.
   - Network / timeout → Left(`NetworkError`).
   - Any non-200 → Left(`UnknownAuthError`) — the function's contract is "always 200 on a parseable request"; non-200 indicates the function itself is malfunctioning.
3. The repository deliberately does NOT distinguish "phone exists with email" / "phone exists without email" / "phone unknown" — the Edge Function's response is always `{ok: true}` and the repository preserves that.

## `sessionStream` semantics

- Backed by Phase 4's `SupabaseClientWrapper.authStateChanges()` (which already maps Supabase's `AuthChangeEvent` to the in-house `AuthState` enum).
- Phase 5's repository wraps that stream and emits a domain-shaped `Session?`:
  - `AuthState.signedIn` → `Session(userId: ..., isActive: true, expiresAt: ...)`.
  - `AuthState.signedOut` → `null`.
  - `AuthState.error` → preceded by a `null` emission and an `AuthFailure` mapping (the repository's `lastFailure` slot, or the bloc's error state).

## Invariants (Constitution IX)

- The `domain/` subfolder of `lib/features/auth/` does NOT import `package:supabase_flutter`.
- The `data/` subfolder is the only place Supabase types appear, and within `data/` only `data/datasources/` and `data/repositories/` reference the SDK.
- The synthetic-email helper lives at `lib/features/auth/data/internal/synthetic_email.dart` — package-private, not exported from any barrel file (Constitution IX defense-in-depth).
