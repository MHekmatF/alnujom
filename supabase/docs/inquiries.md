# inquiries

## Purpose

`public.inquiries` is the Phase 16 parent table for publisher-targeted written
contact submissions. Each row records one inquiry from a visitor (signed-in or
anonymous) to one listing's publisher, with the inquirer's callback phone stored
as Supabase Vault ciphertext per ADR-0001.

Authoritative interface contract:
[`specs/016-contact-inquiries/contracts/phase16-inquiries-table.md`](../../specs/016-contact-inquiries/contracts/phase16-inquiries-table.md).

## Shape

Defined in `supabase/migrations/20260527120001_create_inquiries_table.sql`.
Ten columns; rows are inserted only via the SECURITY DEFINER `submit_inquiry`
RPC (Sub-Phase D); status updates are constrained by the
`enforce_inquiry_transition` BEFORE UPDATE trigger.

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | `uuid` | PK, DEFAULT `gen_random_uuid()` | Stable identifier; used as Vault AAD. |
| `listing_id` | `uuid` | NOT NULL, FK → `public.listings(id)` ON DELETE RESTRICT | Q4=C — listings use soft-delete via `status='deleted'`. |
| `sender_user_id` | `uuid` | NULL, FK → `auth.users(id)` ON DELETE SET NULL | NULL = anonymous submission (FR-008). |
| `sender_name` | `text` | NOT NULL, CHECK `length(trim(sender_name)) BETWEEN 1 AND 100` | FR-006 + Q7=B. |
| `inquirer_phone_encrypted` | `bytea` | NULL | Vault ciphertext; written only by `submit_inquiry`. ADR-0001. |
| `inquirer_phone_key_name` | `text` | NOT NULL, DEFAULT `'app-inquirer-phone-key'` | Vault key identifier (see §Vault encryption). |
| `message` | `text` | NOT NULL, CHECK `length(trim(message)) BETWEEN 1 AND 2000` | Q7=B. |
| `status` | `text` | NOT NULL, DEFAULT `'new'`, CHECK IN (`'new'`,`'seen'`,`'responded'`,`'closed'`,`'spam'`) | Phase 16 lifecycle (FR-013, FR-021a). |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Server-generated. |
| `updated_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Refreshed by `trg_inquiries_set_updated_at`. |

## CHECK constraints

- `sender_name` length 1..100 (trimmed).
- `message` length 1..2000 (trimmed).
- `status` is one of `new`, `seen`, `responded`, `closed`, `spam`.

## Indexes

- `idx_inquiries_listing_created` on `(listing_id, created_at DESC)` — covers
  per-listing chronological reads (FR-015).
- `idx_inquiries_listing_status` on `(listing_id, status, created_at DESC) WHERE
  status IN ('new','seen','responded')` — partial index for active-funnel reads;
  backs `get_inbox_unread_count`.
- `idx_inquiries_sender` on `(sender_user_id) WHERE sender_user_id IS NOT NULL`
  — signed-in inquirer self-read path.

## Triggers

- `trg_inquiries_set_updated_at` — BEFORE UPDATE FOR EACH ROW; maintains
  `updated_at` via the project-wide `public.set_updated_at()` helper from
  `20260506120002_create_profiles.sql`.
- `trg_inquiries_enforce_transition` — BEFORE UPDATE OF `status` FOR EACH ROW;
  enforces the FR-021a + Q2=B transition allowlist; defined in
  `20260527120005_create_enforce_inquiry_transition_trigger.sql`. Allowed pairs:
  `new→seen`, `new→spam`, `seen→responded`, `seen→closed`, `seen→spam`,
  `responded→closed`, `responded→spam`, `closed→seen`, `closed→responded`,
  `closed→spam`. The notable forbidden pair `closed→new` preserves the
  "never been opened" semantics of `new`; `responded→seen` is also forbidden
  (forward-only on the way out per FR-021a). Invalid transitions raise SQLSTATE
  23514 with detail `invalid_inquiry_transition: <OLD> -> <NEW>`.

## Vault encryption (ADR-0001)

The `inquirer_phone_encrypted` column holds the inquirer's callback phone as
ciphertext, encrypted with the Supabase Vault symmetric key named
`app-inquirer-phone-key`. The plaintext phone NEVER lands in any database
column. Encryption is performed exclusively by the SECURITY DEFINER
`submit_inquiry` RPC (Sub-Phase D); decryption is performed exclusively by the
SECURITY DEFINER `decrypt_inquirer_phone(uuid)` function (Sub-Phase D), which
applies the three-tier visibility rule (listing publisher, signed-in original
sender, admin with `inquiries.view_all` permission).

### Vault key one-time setup

The `app-inquirer-phone-key` Vault key MUST be provisioned out-of-band BEFORE
the Sub-Phase D `submit_inquiry` RPC is callable:

```sql
SELECT vault.create_secret(
  gen_random_uuid()::text,
  'app-inquirer-phone-key',
  'Symmetric key for inquirer_phone column encryption (Phase 16, ADR-0001)'
);
```

Re-running this call raises a uniqueness violation, which is acceptable; the
key is created once per project lifetime and never rotated in Phase 16
(rotation strategy is a future-phase concern).

## RLS posture

- **Phase 2 (this migration)**: `ALTER TABLE public.inquiries ENABLE ROW LEVEL
  SECURITY` is set. NO policies are attached. The default-deny posture means
  direct `SELECT`/`INSERT`/`UPDATE`/`DELETE` from `authenticated` and `anon`
  sessions return zero rows or fail closed.
- **Phase 3 (Sub-Phase C, `20260527120003_create_inquiries_policies.sql`)** will
  add the three-tier SELECT policies (`inquiries_select_publisher`,
  `inquiries_select_sender`, `inquiries_select_admin`) per FR-022; the
  publisher-only UPDATE policy (`inquiries_update_publisher`) per FR-024;
  `REVOKE INSERT ON public.inquiries FROM authenticated, anon` to force all
  writes through the `submit_inquiry` RPC; and no DELETE policy (RLS
  default-deny).

## Write path

All client-side writes go through SECURITY DEFINER RPCs in Sub-Phase D:

- Inserts: `public.submit_inquiry(p_listing_id, p_sender_name, p_inquirer_phone,
  p_message)` — validates inputs, encrypts the phone via Vault, captures
  IP/UA into a companion `lead_events` row of type `inquiry_sent`, atomically
  inserts both rows.
- Status updates: a column-restricted `GRANT UPDATE (status) ON public.inquiries
  TO authenticated` permits the publisher (gated by the
  `inquiries_update_publisher` RLS policy) to flip `status` only; the
  transition trigger validates the new value against the allowlist.

Direct `INSERT`/`UPDATE` (of non-`status` columns)/`DELETE` from any client
session is rejected.

## Failure modes

- CHECK violation on `sender_name`, `message`, or `status` → SQLSTATE 23514.
- FK violation on `listing_id` → SQLSTATE 23503.
- Invalid transition (e.g., `closed → new`) → SQLSTATE 23514 raised by the
  trigger with `invalid_inquiry_transition: <OLD> -> <NEW>` detail.
