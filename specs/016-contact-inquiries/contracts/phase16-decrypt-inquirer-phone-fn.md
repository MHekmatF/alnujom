# Contract — `decrypt_inquirer_phone(uuid)` SECURITY DEFINER function

**Owner**: Sub-Phase D (`supabase/migrations/20260527120006_create_decrypt_inquirer_phone_fn.sql`).

**Consumers**: Sub-Phase C `v_inquiries_inbox` view (inlines this in the projection); Sub-Phase E `Inquiry.decryptedPhone` field.

## Signature

```sql
public.decrypt_inquirer_phone(p_inquiry_id UUID) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, vault
STABLE
```

GRANT EXECUTE TO `authenticated`. NOT granted to `anon`.

## Behavior

1. Load the inquiry's encrypted phone column + listing_id + sender_user_id (SECURITY DEFINER bypasses RLS so the row is reachable).
2. Evaluate three-tier visibility:
   - Caller is the original sender (`sender_user_id = auth.uid() AND sender_user_id IS NOT NULL`)
   - OR Caller is the listing's publisher (`l.publisher_user_id = auth.uid()` via lookup on `public.listings`)
   - OR Caller holds the admin permission (`public.current_user_has_permission('inquiries.view_all')`)
3. If unauthorized → RETURN NULL.
4. If authorized → decrypt the BYTEA via `vault.decrypted_secrets` key lookup + `pgsodium.crypto_aead_det_decrypt`. Return plaintext E.164 string.
5. Any decrypt failure (corrupt ciphertext, missing key, key version mismatch) → catch the exception and RETURN NULL per FR-026.

## Pre-conditions

- `public.inquiries` table exists with the inquiry row.
- `public.listings` exists for the listing lookup.
- The `app-inquirer-phone-key` Vault key exists.
- `pgsodium` extension enabled.

## Post-conditions

- For authorized callers + valid ciphertext: returns the E.164 plaintext phone.
- For unauthorized callers OR invalid ciphertext: returns NULL (silent fail — the consumer renders "Phone unavailable" placeholder per FR-026).
- The function is `STABLE` so it can be inlined into views without per-row replanning.

## Failure modes

- Inquiry id doesn't exist → returns NULL (NOT a RAISE EXCEPTION; this is graceful degradation for the view's projection).
- Vault key missing → returns NULL (caught by the EXCEPTION block).
- Corrupt ciphertext → returns NULL.
- Caller is `anon` or non-authorized authenticated → returns NULL (the three-tier check fails).

## Stability surface

**Frozen**: the function name, signature, and return type. Future phases consume it as-is.

**Allowed**: changes to the underlying Vault encryption mechanism (key rotation, algorithm upgrade) provided the input/output remain `uuid → text?`.
