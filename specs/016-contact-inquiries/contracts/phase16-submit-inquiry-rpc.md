# Contract — `submit_inquiry` SECURITY DEFINER RPC

**Owner**: Sub-Phase D (`supabase/migrations/20260527120009_create_submit_inquiry_rpc.sql`).

**Consumers**: Sub-Phase E `SupabaseInquiriesDatasource.submitInquiry`; the only client write-path for inquiries.

## Signature

```sql
public.submit_inquiry(
  p_listing_id      UUID,
  p_sender_name     TEXT,
  p_inquirer_phone  TEXT,
  p_message         TEXT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, vault
```

GRANT EXECUTE TO `authenticated, anon` per FR-008 (anonymous submission allowed).

## Behavior

1. Validate inputs against the table's CHECK constraints (length, regex) — defense-in-depth.
2. Validate `p_listing_id` references an existing `status='approved'` listing AND `publisher_user_id <> auth.uid()` (self-contact gate per FR-001d).
3. Generate the new inquiry's `id` (so we can use it as Vault AAD context).
4. Encrypt `p_inquirer_phone` via `pgsodium.crypto_aead_det_encrypt(plaintext, inquiry_id::text as AAD, key_id)` — deterministic AEAD so a leaked key + known AAD doesn't allow rainbow-table attacks across inquiries.
5. Capture server-side IP (`inet_client_addr()`) and user-agent (`current_setting('request.headers', true)::jsonb->>'user-agent'`).
6. INSERT the `inquiries` row.
7. INSERT the companion `lead_events` row with `event_type = 'inquiry_sent'` + `metadata = jsonb_build_object('ip', ..., 'user_agent', ...)`.
8. RETURN the inquiry's `id`.

Steps 6 + 7 are in the same PL/pgSQL function body so PostgreSQL transaction semantics guarantee both-or-neither atomicity per FR-009 + FR-017.

## Error codes (raised via `RAISE EXCEPTION ... USING ERRCODE`)

| Error | SQLSTATE | Maps to Dart `Failure` |
|-------|----------|------------------------|
| `invalid_sender_name` | 23514 | `Failure.validation('invalid_sender_name')` |
| `invalid_phone` | 23514 | `Failure.validation('invalid_phone')` |
| `invalid_message_length` | 23514 | `Failure.validation('message_too_long')` |
| `listing_not_found` | 23503 | `Failure.notFound('listing')` |
| `listing_not_approved` | 23514 | `Failure.validation('listing_not_approved')` |
| `self_contact_blocked` | 23514 | `Failure.validation('self_contact_blocked')` |

## Pre-conditions

- `public.inquiries` + `public.lead_events` tables exist (Sub-Phase B).
- `app-inquirer-phone-key` Vault key exists.
- `pgsodium` extension enabled.

## Post-conditions

- On success: exactly one row inserted into `public.inquiries` AND exactly one row inserted into `public.lead_events`; the function returns the inquiry id.
- On failure: zero rows inserted in either table (transaction rollback).

## Stability surface

**Frozen**: 4-parameter signature in the order shown; return type `uuid`.

**Allowed**: adding new validation checks (provided existing valid inputs still succeed).
