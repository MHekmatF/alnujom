# Phase 1 Data Model — Auth & Profile

This document specifies the concrete database objects and Flutter domain shapes Phase 5 introduces (or amends), grounded in the spec's FRs and the locked research decisions (R-01..R-21). Every artifact named here corresponds to an artifact named in `plan.md`'s Project Structure section.

---

## 1. SQL artifacts

### 1.1 Enum: `account_approval_status` (NEW)

```sql
CREATE TYPE account_approval_status AS ENUM ('pending', 'approved', 'rejected');
```

- **Idempotency**: wrapped in `DO $$ BEGIN … EXCEPTION WHEN duplicate_object THEN NULL; END $$;` per the Phase 4 R-03 convention.
- **Why narrower than `account_status`**: per R-04 — the request row records the first-review outcome, not the user's broader lifecycle. `suspended`/`deleted` belong on `profiles.account_status`, not here.

### 1.2 Table: `account_approval_requests` (NEW)

```sql
CREATE TABLE IF NOT EXISTS account_approval_requests (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  status           account_approval_status NOT NULL DEFAULT 'pending',
  rejection_reason TEXT NULL,
  reviewed_by      UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at      TIMESTAMPTZ NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT account_approval_requests_rejection_reason_when_rejected CHECK (
    (status = 'rejected' AND rejection_reason IS NOT NULL AND length(trim(rejection_reason)) > 0)
    OR (status <> 'rejected' AND rejection_reason IS NULL)
  ),
  CONSTRAINT account_approval_requests_reviewed_when_decided CHECK (
    (status IN ('approved', 'rejected') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (status = 'pending' AND reviewed_by IS NULL AND reviewed_at IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_account_approval_requests_status_pending
  ON account_approval_requests (created_at DESC)
  WHERE status = 'pending';
```

- **PK**: synthetic UUID (R-20).
- **`user_id` UNIQUE**: one request row per user in Phase 5. Phase 7 may relax to a partial unique index on pending rows if a "reopen rejection" path lands.
- **Cascade**: deleting an `auth.users` row cascades to delete the request row; nulling `reviewed_by` on admin deletion preserves the historical record.
- **Two CHECK constraints** enforce the lifecycle invariants at the database level: rejection always has a reason; pending rows never carry a reviewer; decided rows always do.
- **Partial index** speeds the admin queue's "newest pending first" query — the table will be tiny in v1, but the pattern is the right one and costs negligible storage.
- **`set_updated_at()` trigger** (Phase 4 helper): `CREATE TRIGGER trg_account_approval_requests_set_updated_at BEFORE UPDATE ON account_approval_requests FOR EACH ROW EXECUTE FUNCTION set_updated_at();`. Idempotent via `DROP TRIGGER IF EXISTS … CREATE TRIGGER …`.

### 1.3 Trigger: auto-populate `account_approval_requests` on `profiles` insert (NEW)

```sql
CREATE OR REPLACE FUNCTION auto_create_account_approval_request()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  INSERT INTO account_approval_requests (user_id, status)
  VALUES (NEW.user_id, 'pending')
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_auto_create_account_approval_request ON profiles;
CREATE TRIGGER trg_profiles_auto_create_account_approval_request
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_account_approval_request();
```

- **Why fires on `profiles` insert, not `auth.users` insert**: per R-04. Phase 4's auto-provision trigger creates `profiles` from `auth.users`; piggybacking another side-effect on the auto-provision function would couple two phases. Firing on `profiles` insert keeps the responsibilities cleanly separated.
- **Idempotent**: `ON CONFLICT (user_id) DO NOTHING` absorbs retries (matches Phase 4's R-07 pattern).
- **SECURITY DEFINER**: ensures the trigger inserts into `account_approval_requests` even when the originating `INSERT INTO profiles` runs as a non-privileged role (in practice Phase 4's auto-provision trigger runs as `postgres` so this is belt-and-suspenders).

### 1.4 Column add: `profiles.is_admin` (NEW)

```sql
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN profiles.is_admin IS
  'Phase 5 interim admin flag. Replaced by Phase 6 role/permission system; column dropped in 006-roles-permissions.';
```

- **Default FALSE**: every existing row stays a non-admin after the migration.
- **NOT NULL**: explicit; downstream code can rely on `NOT is_admin` semantics.
- **Comment**: makes the lifecycle explicit for any reviewer who finds the column post-Phase-6 (per `IMPLEMENTATION_PLAN.md` §6 Phase 6 deliverables, Phase 6's `0010_create_user_roles.sql` will drop this column).

### 1.5 Function: `enforce_profile_status_admin_only()` extended (UPDATE)

The existing Phase 4 trigger function is rewritten via `CREATE OR REPLACE FUNCTION` to additionally block client-initiated `is_admin` mutations:

```sql
CREATE OR REPLACE FUNCTION enforce_profile_status_admin_only()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY INVOKER
  SET search_path = public
AS $$
DECLARE
  caller_role TEXT := current_setting('role', true);
  is_privileged BOOLEAN := caller_role IN ('postgres', 'supabase_admin', 'service_role');
BEGIN
  IF is_privileged THEN
    RETURN NEW;  -- privileged sessions bypass per Phase 4 R-12
  END IF;

  -- Phase 4: block account_status / publisher_status mutation by non-privileged callers.
  IF NEW.account_status IS DISTINCT FROM OLD.account_status
     OR NEW.publisher_status IS DISTINCT FROM OLD.publisher_status THEN
    RAISE EXCEPTION 'cannot mutate account_status / publisher_status from a non-privileged session'
      USING ERRCODE = '42501';
  END IF;

  -- Phase 5 addition (FR-009): block is_admin mutation by non-privileged callers.
  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
    RAISE EXCEPTION 'cannot mutate is_admin from a non-privileged session'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;
```

- **No trigger redeclaration needed** — Phase 4 already attached the trigger to `profiles BEFORE UPDATE`; the function-body update is enough.
- **Privileged-role list unchanged**: matches Phase 4 R-12.

### 1.6 Function: `current_user_is_admin()` body swap (UPDATE)

Per R-12:

```sql
CREATE OR REPLACE FUNCTION current_user_is_admin() RETURNS BOOLEAN
LANGUAGE SQL STABLE AS $$
  SELECT COALESCE((SELECT is_admin FROM profiles WHERE user_id = auth.uid()), FALSE);
$$;
```

- **One statement, one definition swap.** Every Phase 4 policy that calls this function picks up the new behavior automatically.
- **No policy file is edited** — Phase 4 R-05 invariant preserved.

### 1.7 Functions: Vault PII helpers (NEW)

Five functions defined in `20260510120004_profiles_vault_pii_helpers.sql`. Full bodies in research R-13. Signatures:

| Function | Signature | Auth gate | Side effect |
|---|---|---|---|
| `app_vault_secret_for_self` | `(field_name TEXT) RETURNS TEXT` | `auth.uid()` resolves caller | Reads `pii.<auth.uid()>.<field_name>` via `app_vault_secret(name)` |
| `app_vault_secret_for_user` | `(p_user_id UUID, field_name TEXT) RETURNS TEXT` | `current_user_is_admin()` | Reads `pii.<p_user_id>.<field_name>`; returns NULL if not admin |
| `app_vault_set_secret_for_self` | `(field_name TEXT, p_value TEXT) RETURNS VOID` | `auth.uid()` resolves caller | Writes `pii.<auth.uid()>.<field_name>` via `vault.create_secret`; allowlists `field_name ∈ {legal_name, national_id}` |
| `app_vault_set_secret_for_user` | `(p_user_id UUID, field_name TEXT, p_value TEXT) RETURNS VOID` | `current_user_is_admin()` | Writes `pii.<p_user_id>.<field_name>`; same allowlist |
| `app_vault_set_private_contact_methods_for_self` | `(p_methods JSONB) RETURNS VOID` | `auth.uid()` resolves caller | Validates `p_methods` is JSON object whose keys ⊆ `{whatsapp, telegram, signal, private_email, secondary_phone}`; writes `pii.<auth.uid()>.private_contact_methods` |

All five are `SECURITY DEFINER` with `SET search_path = public` (and `vault` for the writers).

### 1.8 Functions: account-approval RPCs (NEW)

Two SECURITY DEFINER functions for the admin queue actions, defined in `20260510120001_create_account_approval_requests.sql`:

```sql
CREATE OR REPLACE FUNCTION approve_account_approval_request(p_user_id UUID) RETURNS VOID …
CREATE OR REPLACE FUNCTION reject_account_approval_request(p_user_id UUID, p_reason TEXT) RETURNS VOID …
```

Full bodies in research R-14. Both:
- Check `current_user_is_admin()` first; raise `42501` if false.
- UPDATE the request row (`status`, `rejection_reason`, `reviewed_by`, `reviewed_at`, `updated_at`); raise `02000` if no pending row.
- UPDATE `profiles.account_status` for the same user (with the `account_status = 'pending'` guard so out-of-band changes are not silently overwritten).
- Both UPDATEs in the same transaction — atomic.
- The audit trigger from §1.10 fires once per affected table per the standard PG semantics.

### 1.9 Concrete audit trigger on `account_approval_requests` (NEW)

Per R-05:

```sql
DROP TRIGGER IF EXISTS trg_account_approval_requests_audit_status ON account_approval_requests;
CREATE TRIGGER trg_account_approval_requests_audit_status
  AFTER UPDATE OF status, rejection_reason, reviewed_by, reviewed_at
  ON account_approval_requests
  FOR EACH ROW
  WHEN (
    OLD.status IS DISTINCT FROM NEW.status
    OR OLD.rejection_reason IS DISTINCT FROM NEW.rejection_reason
    OR OLD.reviewed_by IS DISTINCT FROM NEW.reviewed_by
    OR OLD.reviewed_at IS DISTINCT FROM NEW.reviewed_at
  )
  EXECUTE FUNCTION log_audit(
    'account_approval.status_changed',
    'status,rejection_reason,reviewed_by,reviewed_at',
    'user_id'
  );
```

- **Reuses Phase 4's `log_audit()` unchanged** (Phase 4 reusability invariant validated).
- **`WHEN` clause** prevents no-op `UPDATE` statements from emitting spurious audit rows.

### 1.10 RLS policies: `account_approval_requests_policies.sql` (NEW)

Authoring file `supabase/policies/account_approval_requests_policies.sql`; bundled into the table-creation migration via the Phase 4 R-02 inlining pattern with a `# generated from supabase/policies/account_approval_requests_policies.sql` header comment.

```sql
-- generated from supabase/policies/account_approval_requests_policies.sql
ALTER TABLE account_approval_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS account_approval_requests_self_read ON account_approval_requests;
CREATE POLICY account_approval_requests_self_read
  ON account_approval_requests
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS account_approval_requests_admin_read ON account_approval_requests;
CREATE POLICY account_approval_requests_admin_read
  ON account_approval_requests
  FOR SELECT
  TO authenticated
  USING (current_user_is_admin());

DROP POLICY IF EXISTS account_approval_requests_admin_update ON account_approval_requests;
CREATE POLICY account_approval_requests_admin_update
  ON account_approval_requests
  FOR UPDATE
  TO authenticated
  USING (current_user_is_admin())
  WITH CHECK (current_user_is_admin());

-- No INSERT policy: the auto_create_account_approval_request trigger is the only writer.
-- No DELETE policy: rows are kept for audit; cascade from auth.users(id) handles user deletion.
```

| Operation | Roles | Predicate |
|---|---|---|
| `SELECT` (self) | `authenticated` | `user_id = auth.uid()` |
| `SELECT` (admin all) | `authenticated` | `current_user_is_admin()` |
| `UPDATE` | `authenticated` | `current_user_is_admin()` (USING + WITH CHECK) |
| `INSERT` | nobody | trigger-only |
| `DELETE` | nobody | cascade-only |
| Anon | denied | no `TO anon` policies |

### 1.11 Edge Function: `request_password_reset` (NEW)

Per R-07. Full TS shape is the contract (`contracts/request-password-reset-edge-fn.md`); the data-model summary:

- **Trigger**: HTTP POST `/functions/v1/request_password_reset`.
- **Auth**: anonymous (no JWT required; the user is by definition signed-out).
- **Body in**: `{phone: string}` (required).
- **Body out**: `{ok: true}` (always — never reveals whether the phone is known or whether email exists).
- **Service-role usage**: consumes `SUPABASE_SERVICE_ROLE_KEY` from `Deno.env` only; the key is not echoed in any output.
- **Side effects**: `SELECT email FROM profiles WHERE phone = $1` (service-role; bypasses RLS); if the row exists and `email IS NOT NULL` and non-empty, calls `supabase.auth.admin.resetPasswordForEmail(email)`.

---

## 2. Flutter domain entities (Phase 5 additions and amendments)

### 2.1 `Profile` (UPDATE — adds `isAdmin`)

`lib/shared/domain/entities/profile.dart` — Phase 4's existing entity gains one field:

```dart
class Profile extends Equatable {
  final String userId;
  final String? fullName;
  final String? username;
  final PhoneNumber? phone;
  final String? email;
  final String? avatarUrl;
  final AccountStatus accountStatus;
  final PublisherStatus publisherStatus;
  final bool isAdmin;                     // NEW in Phase 5
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.userId,
    this.fullName,
    this.username,
    this.phone,
    this.email,
    this.avatarUrl,
    required this.accountStatus,
    required this.publisherStatus,
    this.isAdmin = false,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    userId, fullName, username, phone, email, avatarUrl,
    accountStatus, publisherStatus, isAdmin, createdAt, updatedAt,
  ];

  Profile copyWith({ /* ... new isAdmin slot included ... */ }) { /* ... */ }
}
```

- **No Supabase imports** (Constitution IX).
- **`PhoneNumber`** is the Phase-5-introduced value object (§2.6).
- **Default `isAdmin = false`** for forward-compat with code paths that don't yet read the column.

### 2.2 `Credentials` (NEW)

`lib/features/auth/domain/entities/credentials.dart`:

```dart
class Credentials extends Equatable {
  final PhoneNumber phone;
  final String password;
  const Credentials({required this.phone, required this.password});
  @override List<Object?> get props => [phone, password];
}
```

### 2.3 `Session` (NEW)

`lib/features/auth/domain/entities/session.dart`:

```dart
class Session extends Equatable {
  final String userId;
  final bool isActive;
  final DateTime? expiresAt;
  const Session({required this.userId, required this.isActive, this.expiresAt});
  @override List<Object?> get props => [userId, isActive, expiresAt];
}
```

### 2.4 `AuthFailure` (NEW)

Sealed-class failure hierarchy. `lib/features/auth/domain/entities/auth_failure.dart`:

```dart
sealed class AuthFailure extends Equatable {
  const AuthFailure();
}
class InvalidPhoneOrPassword extends AuthFailure { ... }
class AccountAlreadyExists extends AuthFailure { ... }
class PasswordTooShort extends AuthFailure { ... }
class NetworkError extends AuthFailure { final Object cause; ... }
class UnknownAuthError extends AuthFailure { final String message; ... }
```

- All localization keys for these failures live in `intl_ar.arb` + `intl_en.arb`. The presentation layer maps each failure case to its key (no string in the failure constructor — keep failure classes localization-free per Constitution V).
- The reset-password path emits no Phase-5-specific failure type. By the account-enumeration-resistance contract (`contracts/request-password-reset-edge-fn.md`), `requestPasswordReset` returns `Right(Unit)` on any parseable input — the user-facing copy is uniform across "phone known with email", "phone known without email", and "phone unknown". Only transport-level failures (network unreachable, 5xx from the Edge Function) surface, mapped to `NetworkError`.

### 2.5 `AccountApprovalRequest` (NEW)

`lib/features/admin/account_approvals/domain/entities/account_approval_request.dart`:

```dart
enum AccountApprovalStatus { pending, approved, rejected }

class AccountApprovalRequest extends Equatable {
  final String id;                     // UUID
  final String userId;                 // UUID
  final AccountApprovalStatus status;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Denormalized snippet for the queue display (joined from profiles in the data layer).
  final String? registrantPhone;
  final String? registrantEmail;
  final String? registrantFullName;

  const AccountApprovalRequest({ ... });
  @override List<Object?> get props => [...];
}
```

- **`AccountApprovalStatus` enum** mirrors the SQL `account_approval_status` enum 1:1.
- **Denormalized fields** are populated by the data-layer query `select('*, profiles!user_id(phone, email, full_name)')` and do not round-trip back to the database.

### 2.6 `PhoneNumber` (NEW)

`lib/shared/domain/value_objects/phone_number.dart` — full contract in `contracts/phone-number-value-object.md`. Domain-shape summary:

```dart
class PhoneNumber extends Equatable {
  final String e164;        // canonical form, e.g. "+963991234567"
  const PhoneNumber._(this.e164);

  static PhoneNumber parse(String raw, {String defaultCountryCode = '+963'});
  static PhoneNumber? tryParse(String raw, {String defaultCountryCode = '+963'});

  @override List<Object?> get props => [e164];
  @override String toString() => e164;
}

class PhoneNumberFormatException implements Exception {
  final String localizationKey;   // e.g. 'phone_invalid'
  PhoneNumberFormatException(this.localizationKey);
}
```

### 2.7 `PrivateContactMethods` (NEW)

`lib/features/profile/domain/entities/private_contact_methods.dart`:

```dart
enum ContactChannel { whatsapp, telegram, signal, privateEmail, secondaryPhone }

class PrivateContactMethods extends Equatable {
  final Map<ContactChannel, String> channels;  // immutable view

  const PrivateContactMethods._(this.channels);

  /// Constructs from a JSON map (typically read from app_vault_secret_for_self).
  /// Rejects unknown keys (rare given the SQL allowlist enforces them, but defense-in-depth).
  static PrivateContactMethods fromJson(Map<String, dynamic> json);

  /// Serializes to the JSON shape the app_vault_set_private_contact_methods_for_self expects.
  Map<String, dynamic> toJson();

  @override List<Object?> get props => [channels];
}
```

### 2.8 `OnboardingState` (NEW — presentation-only)

`lib/features/onboarding/domain/value_objects/onboarding_state.dart`:

```dart
enum OnboardingState { firstLaunch, seen }
```

- Read and written via the `OnboardingRepository` interface. `firstLaunch` → show onboarding; `seen` → skip.

### 2.9 `AuthState` machine (presentation/bloc)

Per R-18. Sealed-class hierarchy in `lib/features/auth/presentation/bloc/auth_state.dart`:

| State | Carries | When |
|---|---|---|
| `Unauthenticated` | nothing | App boot before sign-in; after sign-out |
| `Authenticating` | nothing | Mid-API-call for register/login/reset |
| `Authenticated` | `Profile` | Sign-in succeeded AND `profile.accountStatus == approved` |
| `PendingApproval` | `Profile` | Sign-in succeeded AND `profile.accountStatus == pending` |
| `Rejected` | `Profile`, `String reason` | Sign-in succeeded AND `profile.accountStatus == rejected` |
| `Suspended` | `Profile` | Sign-in succeeded AND `profile.accountStatus == suspended` |
| `AuthError` | `AuthFailure` | API failure surfaced for UI display |

The `go_router` redirect helper does an exhaustive `switch` over this state to compute the destination route. `AuthState.deleted` is not represented (no `deleted` lifecycle in v1 per the Session 2026-05-10 account-status-enum-scope clarification).

---

## 3. RLS posture summary (Phase 4 + Phase 5)

| Table | RLS enabled | Self-read | Self-write | Admin-read | Admin-write | Anon | Notes |
|---|---|---|---|---|---|---|---|
| `profiles` (Phase 4) | ✅ | non-status fields | non-status fields | yes (via `current_user_is_admin()`) | status + `is_admin` (privileged sessions only) | denied | Phase 5 swaps `current_user_is_admin()` body |
| `user_preferences` (Phase 4) | ✅ | yes | yes | — | — | denied | Self-only; no admin policy (Phase 4) |
| `audit_logs` (Phase 4) | ✅ | — | — | yes (via `current_user_is_admin()`) | — | denied | No client write; trigger-only writes |
| `account_approval_requests` (Phase 5) | ✅ | yes | — | yes | yes (status, reason, reviewer fields) | denied | No client INSERT; trigger-only. No DELETE; cascade-only. |
| `vault.secrets` (Supabase platform) | ✅ (platform default) | — | — | — | — | denied | Reads/writes only via SECURITY DEFINER helpers (R-13) |

---

## 4. State transitions (lifecycle summary)

### 4.1 `account_approval_requests.status`

```
       (auto-trigger on profiles insert)
                  |
                  v
          [pending]  -- approve_account_approval_request -->  [approved]  (terminal in v1)
              |
              +-- reject_account_approval_request(reason)  -->  [rejected]  (terminal in v1)
```

- Both transitions write `reviewed_by = auth.uid()`, `reviewed_at = now()`.
- The CHECK constraints prevent invalid state combinations.
- `[approved]` and `[rejected]` are terminal in v1 — Phase 7 super-admin UI may add transitions back to `[pending]` (reopen rejection); when it does, that phase's spec relaxes the `UNIQUE (user_id)` constraint to a partial index.

### 4.2 `profiles.account_status`

```
       (auto-trigger on auth.users insert)
                  |
                  v
          [pending]  -- approve  -->  [approved]  -- (Phase 7) suspend  -->  [suspended]
              |                              ^                                      |
              |                              +-- (Phase 7) un-suspend  -------------+
              +-- reject  -->  [rejected]
```

- In Phase 5, only `pending → approved` and `pending → rejected` are reachable via the admin queue.
- `approved → suspended` is reachable via privileged SQL (R-21).
- `suspended → approved` and `rejected → pending` (reopen) are NOT reachable in Phase 5 (deferred to Phase 7).
- `[deleted]` is unused in v1.

### 4.3 `AuthBloc` state machine

(See R-18 / §2.9 above. Transitions are computed by the bloc from the cross-product of `Session?` and `Profile.accountStatus`.)

---

## 5. Vault secret naming convention

Per R-13:

| Secret name | Type | Source field | Read helper | Write helper |
|---|---|---|---|---|
| `pii.<user_id>.legal_name` | TEXT | user-typed | `app_vault_secret_for_self('legal_name')` | `app_vault_set_secret_for_self('legal_name', ...)` |
| `pii.<user_id>.national_id` | TEXT | user-typed | `app_vault_secret_for_self('national_id')` | `app_vault_set_secret_for_self('national_id', ...)` |
| `pii.<user_id>.private_contact_methods` | JSON-serialized object | user-typed (typed-key allowlist) | `app_vault_secret_for_self('private_contact_methods')` (returns the JSON-serialized text — the data layer parses it) | `app_vault_set_private_contact_methods_for_self(p_methods JSONB)` |

- `<user_id>` is always the literal text representation of the UUID with hyphens (Postgres default `uuid::text` shape, e.g., `pii.5b9b...12d3.legal_name`).
- The naming convention is enforced by the helper functions; no caller constructs the secret name directly.

---

## 6. Validation rules (domain layer)

Per R-17. Recapped here so this document is the one-stop data-contract reference:

| Field | Rule | Failure |
|---|---|---|
| `Profile.fullName` | trimmed length 1..100 chars | `InvalidFullName` |
| `Profile.username` | `[a-z0-9_]{3,30}` | `InvalidUsername` |
| `Profile.username` (unique) | Postgres `'23505'` on `profiles_username_key` | `UsernameTaken` |
| `Profile.email` | optional; basic RFC-shape regex | `InvalidEmail` |
| `Profile.avatarUrl` | optional; HTTPS URL | `InvalidAvatarUrl` |
| `PhoneNumber` | E.164; Syrian numbers normalized to `+963` | `PhoneNumberFormatException` |
| `Credentials.password` | length >= 8 | `PasswordTooShort` |
| `PrivateContactMethods` | keys ⊆ `{whatsapp, telegram, signal, privateEmail, secondaryPhone}` | rejected at construction |
| `PrivateContactMethods.secondaryPhone` value | parses as `PhoneNumber` | mapped to `InvalidPhone` |

---

## 7. Migration ordering (recap from R-01)

Five new migrations under `supabase/migrations/`:

1. `20260510120001_create_account_approval_requests.sql` (table + auto-trigger + RLS policies + RPCs `approve_account_approval_request` / `reject_account_approval_request`)
2. `20260510120002_profiles_add_is_admin.sql` (`is_admin` column + extended `enforce_profile_status_admin_only`)
3. `20260510120003_swap_admin_predicate.sql` (`current_user_is_admin()` body swap — must run AFTER `is_admin` column exists)
4. `20260510120004_profiles_vault_pii_helpers.sql` (the five Vault PII helpers — must run AFTER admin predicate is real)
5. `20260510120005_attach_audit_trigger_account_approval_requests.sql` (audit trigger reusing `log_audit()`)

Order matters: migration 3 reads `profiles.is_admin` which migration 2 adds; migration 4's admin-gated helpers call `current_user_is_admin()` whose new body is set by migration 3.
