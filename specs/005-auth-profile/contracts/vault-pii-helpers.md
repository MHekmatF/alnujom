# Contract: Vault PII Helpers

**Owner**: Phase 5 (`supabase/migrations/20260510120004_profiles_vault_pii_helpers.sql`).
**Consumers**: Phase 5's profile-private page (read+write self); Phase 5's admin-side decryption (read other users — out of UI scope in v1, but the helper exists for Phase 7's super-admin UI). Phase 16+ inquiries' inquirer-phone Vault flow will follow the same `app_vault_secret_for_*` naming pattern but with a different secret-name prefix.
**Stability**: Stable across the v1 lifecycle. The helper signatures and the secret-naming convention `pii.<user_id>.<field_name>` are the contract; the body may evolve (e.g., a future phase might add a logging hook) but the call shape from the data layer does not.

---

## Purpose

Five SECURITY DEFINER SQL functions that mediate every read and write of the three Vault-stored PII fields (`legal_name`, `national_id`, `private_contact_methods`). The helpers enforce:

- The secret name is always `pii.<user_id>.<field_name>` — callers cannot construct arbitrary secret names.
- The `field_name` parameter is allowlisted to `{legal_name, national_id, private_contact_methods}`.
- For `private_contact_methods`, the JSON keys are allowlisted to `{whatsapp, telegram, signal, private_email, secondary_phone}`.
- Self helpers are scoped to `auth.uid()`; cross-user reads/writes go through the explicit `for_user` variants gated on `current_user_is_admin()`.

## Function table

| Function | Signature | Auth | Side effect |
|---|---|---|---|
| `app_vault_secret_for_self` | `(field_name TEXT) RETURNS TEXT` | `auth.uid()` | Reads `pii.<auth.uid()>.<field_name>` via Phase 4's `app_vault_secret(name)` |
| `app_vault_secret_for_user` | `(p_user_id UUID, field_name TEXT) RETURNS TEXT` | `current_user_is_admin()` | Reads `pii.<p_user_id>.<field_name>`; returns NULL on non-admin |
| `app_vault_set_secret_for_self` | `(field_name TEXT, p_value TEXT) RETURNS VOID` | `auth.uid()` | Writes `pii.<auth.uid()>.<field_name>`; allowlists `field_name ∈ {legal_name, national_id}` |
| `app_vault_set_secret_for_user` | `(p_user_id UUID, field_name TEXT, p_value TEXT) RETURNS VOID` | `current_user_is_admin()` | Same write path with admin gating |
| `app_vault_set_private_contact_methods_for_self` | `(p_methods JSONB) RETURNS VOID` | `auth.uid()` | Validates JSON object + key allowlist; writes `pii.<auth.uid()>.private_contact_methods` |

All five are `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public[, vault]`.

## Read contract

```dart
// Data-layer caller, via Postgrest RPC:
final legalName = await supabase
  .rpc('app_vault_secret_for_self', params: {'field_name': 'legal_name'})
  .single() as String?;
```

| Scenario | Returned value |
|---|---|
| Caller is unauthenticated (no JWT) | NULL (auth.uid() is NULL → first IF returns NULL) |
| Caller is authenticated, secret exists | The decrypted plaintext (TEXT) |
| Caller is authenticated, secret does not exist | NULL |
| `field_name` not in allowlist | RAISE EXCEPTION `22023` (mapped by data layer to `InvalidFieldName` failure; should never reach a real user given the data layer always passes allowlisted names) |
| `app_vault_secret_for_user` called by a non-admin | NULL (silent — does NOT raise; the policy is "no information leak") |
| `app_vault_secret_for_user` called by admin | The decrypted plaintext |

## Write contract

```dart
// User updating their own legal_name:
await supabase.rpc('app_vault_set_secret_for_self',
  params: {'field_name': 'legal_name', 'p_value': 'Hekmat ...'});

// User updating their own contact methods:
await supabase.rpc('app_vault_set_private_contact_methods_for_self',
  params: {'p_methods': {'whatsapp': '+963991234567', 'telegram': '@hekmat'}});
```

| Scenario | Behavior |
|---|---|
| Caller is unauthenticated | RAISE EXCEPTION `42501` |
| Caller passes `field_name = 'private_contact_methods'` to the TEXT setter | RAISE EXCEPTION `22023` (steers caller to the JSON setter) |
| Caller passes a `field_name` not in `{legal_name, national_id}` to the TEXT setter | RAISE EXCEPTION `22023` |
| Caller passes a JSON value with an unknown key to the contact-methods setter | RAISE EXCEPTION `22023` (e.g., `unknown channel key: skype`) |
| Caller passes a non-object JSON to the contact-methods setter | RAISE EXCEPTION `22023` |
| Admin caller passes any of the above to the `for_user` setter without admin gate | RAISE EXCEPTION `42501` |
| All checks pass | `vault.create_secret(value, name, description)` runs; the function returns VOID. `vault.create_secret` is idempotent on `name` per the Supabase Vault docs — second calls update the value rather than raising. |

## Secret naming convention

For every helper:

- `field_name` is `legal_name`, `national_id`, or `private_contact_methods`.
- `<user_id>` is the UUID's text representation (Postgres default `uuid::text`, e.g., `5b9b...12d3`).
- The full name is `format('pii.%s.%s', <user_id>, field_name)`.

Examples:

```
pii.5b9b1234-1234-1234-1234-123456789012.legal_name
pii.5b9b1234-1234-1234-1234-123456789012.national_id
pii.5b9b1234-1234-1234-1234-123456789012.private_contact_methods
```

## Interaction with Phase 4's `app_vault_secret(name)`

The four read paths (`app_vault_secret_for_self`, `app_vault_secret_for_user`) wrap Phase 4's existing `app_vault_secret(name TEXT) RETURNS TEXT` helper unchanged — they construct the deterministic name and delegate. Phase 4's contract is preserved exactly.

The write paths use `vault.create_secret(...)` directly (Phase 4's helper is read-only by design).

## Invariants

- **No caller-controlled secret names**: every helper deterministically constructs the name from `auth.uid()` (or `p_user_id` after admin check) plus the allowlisted `field_name`. A malicious caller cannot read or write `pii.<other_user>.legal_name` — the self helpers bind to `auth.uid()`; the admin helpers gate on `current_user_is_admin()`.
- **No information leak on missing secret or non-admin**: returns NULL silently. The user-facing UX (e.g., "you haven't set this yet") is decided by the data-layer caller, not the helper.
- **Idempotent writes**: setting the same value twice is a no-op past the first call (per `vault.create_secret`'s upsert semantics on `name`).
- **No plaintext in `audit_logs`**: PII writes do NOT trigger an audit-log row in Phase 5 — `vault.secrets` writes are not audit-trigger-attached. (Phase 7+ may add a metadata-only audit pattern that records "user X updated their PII at time Y" without capturing the plaintext.)

## Verification

```sql
-- Read self (zero state).
SELECT app_vault_secret_for_self('legal_name'); -- Expected: NULL

-- Write self.
SELECT app_vault_set_secret_for_self('legal_name', 'Test Name');
SELECT app_vault_secret_for_self('legal_name'); -- Expected: 'Test Name'

-- Allowlist guard.
SELECT app_vault_secret_for_self('not_a_field'); -- Expected: RAISES 22023

-- Cross-user read attempt as non-admin.
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<other-user>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT app_vault_secret_for_user('<first-user>'::uuid, 'legal_name'); -- Expected: NULL (silent)
RESET ROLE;

-- Cross-user read as admin.
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<admin-user>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT app_vault_secret_for_user('<first-user>'::uuid, 'legal_name'); -- Expected: 'Test Name'
RESET ROLE;

-- Contact-methods JSON validation.
SELECT app_vault_set_private_contact_methods_for_self('{"skype": "..."}'::jsonb); -- Expected: RAISES 22023 with message including 'unknown channel key: skype'
SELECT app_vault_set_private_contact_methods_for_self('{"whatsapp": "+963991234567"}'::jsonb); -- Expected: success
SELECT app_vault_secret_for_self('private_contact_methods')::jsonb; -- Expected: {"whatsapp": "+963991234567"}

-- pg_dump check (per ADR-0001 verification).
-- Expected: the values 'Test Name', 'Hekmat ...' do NOT appear in plaintext anywhere outside vault.secrets ciphertext.
```
