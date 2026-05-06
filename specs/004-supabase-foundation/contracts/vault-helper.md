# Contract: `app_vault_secret(name)` Vault-Read Helper

**Owner**: Phase 4 (`supabase/migrations/20260506120006_enable_vault.sql` defines the function and enables the `pgsodium` extension).
**Consumers**: Phase 5 (admin decrypt of `legal_name`/`national_id`/`private_contact_methods`), Phase 16 (inquirer phone), Phase 19 (agency verification ID), Phase 21 (third-party ad-network keys), Phase 22 (FCM service-account JSON). Every consumer reads via this helper; none reads `vault.decrypted_secrets` directly.
**Stability**: **The signature is stable across the entire v1 lifecycle.** Later phases that need a different return shape do `app_vault_secret(name)::jsonb` (or another cast) at the call site rather than introducing a parallel function.

---

## Purpose

A single, narrowly-scoped wrapper around the Supabase Vault API that reads a secret by name. Returns the decrypted value or NULL — never raises for missing names, so callers can treat "not present" the same as "empty result." This is the canonical read path for every backend secret and admin-only PII column the project encrypts via Vault per ADR-0001.

## Function

```
app_vault_secret(p_name TEXT) RETURNS TEXT
```

- **Language**: SQL.
- **Security**: `SECURITY DEFINER` (needs to read `vault.decrypted_secrets`, which is admin-only by Supabase platform default).
- **Volatility**: `STABLE`.

## Body

```sql
CREATE OR REPLACE FUNCTION app_vault_secret(p_name TEXT) RETURNS TEXT
LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = p_name LIMIT 1;
$$;
```

## Behavior

- **Hit**: Returns the decrypted secret value as TEXT.
- **Miss** (no row matches `p_name`): Returns NULL. No exception raised.
- **Empty `p_name`** (`''`): Treated like a miss — no row matches, returns NULL.

The `LIMIT 1` clause ensures the function returns at most one value even if (defensively) multiple rows ever exist with the same `name`. Supabase Vault enforces uniqueness on `name`, but `LIMIT 1` makes the function defensive against schema changes.

## Phase 4 storage state

**Phase 4 stores ZERO application-level secrets.** The function exists, the Vault scaffolding is in place, but nothing has been written to it yet. This is by design — Phase 4 is forward-prep for Phases 5/16/19/21/22 per ADR-0001 (FR-013).

The Phase 4 verification (User Story 4) confirms the function returns NULL for every name. The first phase that writes a secret (Phase 5, for the per-user PII Vault columns) does so via its own migration; Phase 4's `20260506120006_enable_vault.sql` does not contain any `INSERT INTO vault.secrets` statement.

## Caller patterns (illustrative, owned by later phases)

```sql
-- Phase 22 — read the FCM service-account JSON in an Edge Function
SELECT app_vault_secret('fcm_service_account')::jsonb;

-- Phase 5 — admin-only decrypt of a profile's national_id
SELECT
  user_id,
  CASE WHEN current_user_is_admin()
    THEN app_vault_secret('profile.' || user_id::text || '.national_id')
    ELSE NULL
  END AS national_id_decrypted
FROM profiles WHERE user_id = '<id>';

-- Phase 16 — read an inquiry's vault-stored phone (publisher-only)
SELECT
  i.id,
  CASE WHEN i.publisher_user_id = auth.uid() OR current_user_is_admin()
    THEN app_vault_secret('inquiry.' || i.id::text || '.phone')
    ELSE NULL
  END AS inquirer_phone
FROM inquiries i WHERE i.id = '<id>';
```

The naming convention for secret names (`<scope>.<id>.<field>` for per-row PII, `<service>_<purpose>` for backend-wide secrets) is locked by the phase that introduces each kind of secret; Phase 4 doesn't enforce it because Phase 4 stores none.

## What MUST NOT happen

- Callers MUST NOT read `vault.decrypted_secrets` directly. The wrapper exists so future implementation changes (different vault backend, different decryption path) are localized to the function body.
- Callers MUST NOT wrap this function in a `CASE WHEN ... IS NULL THEN RAISE ...` that would re-introduce the missing-name-as-error semantics — the contract is "missing = NULL." Callers that need an error MUST raise it explicitly themselves with a clear message.
- The function MUST NOT be `SECURITY INVOKER` — every consumer needs the elevated read on `vault.decrypted_secrets`.
- Phase 4 MUST NOT store any secret. Any `INSERT INTO vault.secrets` statement that lands in `20260506120006_enable_vault.sql` is a defect.

## Verification (Phase 4 quickstart)

```sql
-- 1. Confirm pgsodium is enabled.
SELECT extname FROM pg_extension WHERE extname = 'pgsodium';
-- Expect: 1 row.

-- 2. Confirm the function exists.
SELECT proname, prorettype::regtype, proargtypes::regtype[], prosecdef, provolatile
  FROM pg_proc WHERE proname = 'app_vault_secret';
-- Expect: proname='app_vault_secret', prorettype='text', proargtypes=['text'], prosecdef=true, provolatile='s'.

-- 3. Call with a name that does not exist.
SELECT app_vault_secret('does_not_exist');
-- Expect: NULL. No error.

-- 4. Confirm the Vault is empty (Phase 4 stores no secrets).
SELECT COUNT(*) FROM vault.secrets;
-- Expect: 0 (or however many platform-managed secrets exist; application-level secret count = 0).
```
