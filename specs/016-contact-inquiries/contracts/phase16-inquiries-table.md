# Contract — `public.inquiries` table

**Owner**: Sub-Phase B (`supabase/migrations/20260527120001_create_inquiries_table.sql`).

**Consumers**: Sub-Phase C policies + views; Sub-Phase D RPCs + decrypt function; Sub-Phase E data source + DTO; Phase 17 (favorites — no schema change required); Phase 18 (reports/moderation — may add new policies but MUST NOT alter columns); Phase 20 (admin dashboard counters).

## Columns (frozen surface)

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | UUID | PK, DEFAULT `gen_random_uuid()` | Stable identifier; used as Vault AAD for encryption. |
| `listing_id` | UUID | NOT NULL, FK → `public.listings(id)` ON DELETE RESTRICT | Q4=C. |
| `sender_user_id` | UUID | NULL, FK → `auth.users(id)` ON DELETE SET NULL | NULL = anonymous submission per FR-008. |
| `sender_name` | TEXT | NOT NULL, CHECK length 1..100 | FR-006, Q7=B for the 100 cap. |
| `inquirer_phone_encrypted` | BYTEA | NULL | Vault ciphertext; never set directly by clients — only by `submit_inquiry` RPC. ADR-0001. |
| `inquirer_phone_key_name` | TEXT | NOT NULL, DEFAULT `'app-inquirer-phone-key'` | Vault key identifier. |
| `message` | TEXT | NOT NULL, CHECK length 1..2000 | Q7=B. |
| `status` | TEXT | NOT NULL, DEFAULT `'new'`, CHECK IN (new, seen, responded, closed, spam) | IMPLEMENTATION_PLAN §6.3. |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `now()` | Server-generated; never client-supplied. |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `now()`, refreshed by `set_updated_at` trigger | Refreshes on every UPDATE. |

## Indexes

- `idx_inquiries_listing_created` on `(listing_id, created_at DESC)` — covers the per-listing chronological reads.
- `idx_inquiries_listing_status` on `(listing_id, status, created_at DESC) WHERE status IN ('new','seen','responded')` — partial index for the active-funnel reads (also backs `get_inbox_unread_count`).
- `idx_inquiries_sender` on `(sender_user_id) WHERE sender_user_id IS NOT NULL` — covers the signed-in inquirer self-read path.

## RLS

`ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY` is set in this migration. Policies land in Sub-Phase C (`20260527120003_create_inquiries_policies.sql`).

## Pre-conditions

- `public.listings` exists (Phase 10).
- `auth.users` exists (Supabase baseline).
- `public.set_updated_at()` exists (Phase 4).
- The `app-inquirer-phone-key` Vault key exists (one-time setup per `data-model.md` §1).

## Post-conditions

- Every row of `public.inquiries` carries an encrypted `inquirer_phone_encrypted` populated by `submit_inquiry` (no direct INSERTs from clients per Sub-Phase C INSERT-revocation).
- Soft-deleting a listing (via `listings.status = 'deleted'`) leaves inquiries on it intact (the FK is `RESTRICT` but the soft-delete doesn't violate it).
- The `status` column never holds a value outside the 5-element enum.

## Failure modes

- Inserting a row violating any CHECK constraint raises SQLSTATE 23514 (CHECK violation).
- Inserting a row with an invalid `listing_id` raises SQLSTATE 23503 (FK violation).
- Direct INSERT/DELETE attempts from `authenticated` or `anon` are rejected by REVOKE INSERT/DELETE applied in Sub-Phase C.

## Stability surface

**Frozen** (Phase 17/18/20 MUST NOT alter):

- Column names and types.
- The CHECK on `message` (1..2000 chars).
- The CHECK on `status` (5-element enum).
- The FK ON DELETE RESTRICT on `listing_id`.

**Allowed to change in future phases**:

- Adding new columns (must be NULL-default or have a sensible default).
- Adding new indexes.
- Adding new RLS policies (must not remove existing ones).
- Adding new statuses to the CHECK enum (e.g., a future `archived` state).
