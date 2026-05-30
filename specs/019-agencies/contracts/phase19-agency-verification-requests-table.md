# Contract — `public.agency_verification_requests` table

**File**: `supabase/migrations/20260531120003_create_agency_verification_requests_table.sql` (Sub-Phase B). Full SQL in `data-model.md §1.3`. Structurally mirrors the Phase 5 `account_approval_requests` (`20260510120001`).

## Columns

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `agency_id` | UUID NOT NULL | FK `agencies(id)` `ON DELETE CASCADE` |
| `decision` | TEXT NOT NULL | DEFAULT `'pending'`; `CHECK IN ('pending','approved','rejected')` |
| `decision_reason` | TEXT NULL | required-when-rejected, null-otherwise CHECK |
| `evidence_urls` | JSONB NULL | storage paths in `agency-documents` |
| `submitted_by` | UUID NULL | FK `auth.users(id)` `ON DELETE SET NULL` |
| `submitted_at` | TIMESTAMPTZ NOT NULL | `now()` |
| `reviewed_by`,`reviewed_at` | UUID/TIMESTAMPTZ NULL | reviewed-when-decided CHECK |
| `created_at`,`updated_at` | TIMESTAMPTZ NOT NULL | `set_updated_at()` trigger |

The ID-document number + commercial-registration number are **NOT columns** — they go to Vault (`app_vault_set_agency_secret`, contract `phase19-agency-write-rpcs`).

## Constraints

- `ux_agency_open_verification (agency_id) WHERE decision='pending'` — at most one OPEN request per agency (a fresh request may follow a rejection).
- `agency_verification_reason_when_rejected` + `agency_verification_reviewed_when_decided` CHECKs (the account-approval template).

RLS enabled — readable by an agency-admin of that agency OR `agencies.view` (policies contract).

## Smoke tests

1. `submit_agency_verification` inserts a `pending` row; a 2nd while one is open → `23505` (ux index).
2. The Vault ID number is absent from the row and from every client-readable view.
3. `moderate_agency_internal('approve'|'reject')` flips `decision` + sets `reviewed_by`/`reviewed_at` (+ `decision_reason` on reject); the audit trigger fires.
