# agency_verification_requests

## Purpose

`public.agency_verification_requests` is the Phase 19 agency-verification store.
Each row is one verification submission for one agency. It **structurally
mirrors** the Phase 5 `account_approval_requests` (`20260510120001`): the same
required-reason-when-rejected and reviewed-when-decided CHECK invariants, the
same `set_updated_at` trigger. The verification ID-document number and the
commercial-registration number are **NOT columns here** — they are admin-only PII
and go to Supabase Vault (ADR-0001), written by `app_vault_set_agency_secret`
(Migration …007). At most one OPEN (pending) request may exist per agency
(FR-004).

Authoritative interface contract:
[`specs/019-agencies/contracts/phase19-agency-verification-requests-table.md`](../../specs/019-agencies/contracts/phase19-agency-verification-requests-table.md).

## Shape

Defined in `supabase/migrations/20260531120003_create_agency_verification_requests_table.sql`.
Direct client writes are blocked at the table level (Migration …005 revokes
INSERT/UPDATE/DELETE) so every row originates from the `submit_agency_verification`
SECURITY DEFINER RPC (Migration …008), and every decision flows through the
service-role `moderate_agency_internal` RPC (Migration …010).

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | `uuid` | PK, DEFAULT `gen_random_uuid()` | Request identifier. |
| `agency_id` | `uuid` | NOT NULL, FK -> `public.agencies(id)` ON DELETE CASCADE | The agency under review. |
| `decision` | `text` | NOT NULL, DEFAULT `'pending'`, CHECK in {`pending`,`approved`,`rejected`} | Review outcome. |
| `decision_reason` | `text` | NULL | Required (`length>0`) when `decision='rejected'`; must be NULL otherwise (CHECK). Surfaced to the owner (FR-009). |
| `evidence_urls` | `jsonb` | NULL | Storage paths in the `agency-documents` bucket. |
| `submitted_by` | `uuid` | NULL, FK -> `auth.users(id)` ON DELETE SET NULL | The submitting agency-admin (attribution survives deletion). |
| `submitted_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Server-generated; drives queue newest-first ordering. |
| `reviewed_by` | `uuid` | NULL, FK -> `auth.users(id)` ON DELETE SET NULL | The deciding platform admin. |
| `reviewed_at` | `timestamptz` | NULL | When the decision was made. |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Server-generated. |
| `updated_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Maintained by the Phase 4 `set_updated_at` trigger. |

Two CHECK constraints enforce lifecycle invariants (the account-approval template):

- `agency_verification_reason_when_rejected` — a rejected row always carries a
  non-empty `decision_reason`; pending/approved rows have
  `decision_reason IS NULL`.
- `agency_verification_reviewed_when_decided` — pending rows have
  `reviewed_by IS NULL` AND `reviewed_at IS NULL`; decided (approved/rejected)
  rows have both populated.

## Vault note (ADR-0001)

The verification **ID-document number** and **commercial-registration number** are
NOT stored on this table. They are written to Supabase Vault under the namespace
`pii.agency.{agency_id}.{field}` by `app_vault_set_agency_secret` (Migration …007)
and are decryptable only by an `agencies.view` holder via
`app_vault_secret_for_agency` (R-141 / FR-005). They never appear in any
client-readable column or view.

## Lifecycle

`pending → approved | rejected`. A `submit_agency_verification` call inserts a
`pending` row (and stores the two Vault numbers); `moderate_agency_internal`
('approve'|'reject') flips `decision`, sets `reviewed_by`/`reviewed_at`, and (on
reject) sets `decision_reason`. A fresh request may follow a rejection.

## Indices

| Index | Definition | Purpose |
|-------|-----------|---------|
| `ux_agency_open_verification` | UNIQUE `(agency_id) WHERE decision = 'pending'` | At most one OPEN request per agency (FR-004). A 2nd submit while one is open raises `23505`. A fresh request may follow a rejection (terminal rows fall outside the predicate). |
| `idx_agency_verification_decision` | `(decision, submitted_at DESC)` | Admin verification queue: newest-first by decision. |

## FK delete behaviors (R-144)

| FK column | References | ON DELETE behavior | Rationale |
|-----------|-----------|-------------------|-----------|
| `agency_id` | `public.agencies(id)` | **CASCADE** | Deleting an agency removes its verification requests with no orphans. |
| `submitted_by` | `auth.users(id)` | **SET NULL** | The request survives the submitter's account deletion. |
| `reviewed_by` | `auth.users(id)` | **SET NULL** | The request survives the reviewing admin's account deletion (attribution goes null, row stays). |

## RLS posture (forward-stated)

- **Migration 3 (this file)**: `ALTER TABLE public.agency_verification_requests
  ENABLE ROW LEVEL SECURITY` is set. NO policies are attached. Default-deny means
  direct reads return zero rows until Migration …005 attaches the reader policy.
- **Migration …005 (`20260531120005_create_agency_policies.sql`)** will add:
  - `agency_verification_select` — SELECT for `authenticated` where
    `public.is_agency_admin(agency_id) OR
    public.current_user_has_permission('agencies.view')` (an agency-admin of that
    agency sees its requests; agents do not; a platform admin sees all).
  - `REVOKE INSERT, UPDATE, DELETE ON public.agency_verification_requests FROM
    authenticated, anon` — submission via `submit_agency_verification`, decisions
    via `moderate_agency_internal` only.
  - No `anon` policy.

The full live reader/writer matrix (data-model §1.14) is appended to this doc in
Sub-Phase C (T022).

## Live RLS reader/writer matrix (Sub-Phase C, Migration …005)

Attached by `supabase/migrations/20260531120005_create_agency_policies.sql`
(load-bearing — Principle III, data-model §1.14):

| Actor | `agencies` SELECT | `agency_members` SELECT | `agency_verification_requests` SELECT | any table INSERT/UPDATE/DELETE | Vault id/registration |
|-------|-------------------|--------------------------|----------------------------------------|--------------------------------|------------------------|
| Anonymous | ✅ only `status='approved'` | ❌ | ❌ | ❌ | ❌ |
| Authenticated non-member | ✅ approved only | ✅ own invitation row only | ❌ | ❌ (RPC only) | ❌ |
| Owner / active member | ✅ own agency (any status) | ✅ own agency roster | agency-admins ✅ / agents ❌ | ❌ (RPC only) | ❌ (admin-decrypt only) |
| `agencies.view`/`approve`/`suspend` holder | ✅ ALL | ✅ ALL | ✅ ALL | ❌ (moderate_agency → service-role RPC only) | ✅ via `app_vault_secret_for_agency` |
| `service_role` (Edge Fn) | n/a (bypasses RLS) | n/a | n/a | via `moderate_agency_internal` only | n/a |

`agency_verification_requests` policy (Migration …005):

- `agency_verification_select` — `TO authenticated USING
  (public.is_agency_admin(agency_id) OR
  public.current_user_has_permission('agencies.view'))` — an agency-admin of that
  agency sees its requests; agents do NOT; an `agencies.view` holder sees all.
- `REVOKE INSERT, UPDATE, DELETE ON public.agency_verification_requests FROM
  authenticated, anon` — submission via `submit_agency_verification`, decisions via
  `moderate_agency_internal` only.
- No `anon` policy.

The Vault ID-document + commercial-registration numbers are NEVER in any policy-
readable column and NEVER in `v_agencies` (the SECURITY DEFINER directory view,
Migration …006, projects public profile fields only). They are decryptable solely
by an `agencies.view` holder via `app_vault_secret_for_agency` (R-141 / FR-005).

## Audit trigger (Migration …011)

`supabase/migrations/20260531120011_create_agency_audit_triggers.sql` attaches
`trg_agency_verification_audit` — `AFTER UPDATE OF decision … WHEN (OLD.decision IS
DISTINCT FROM NEW.decision) EXECUTE FUNCTION
log_audit('agency_verification.decided', 'decision,decision_reason,reviewed_by',
'id')` — reusing the Phase 4 `log_audit()` emitter (FR-012/FR-041). The actor is
read from `app.current_user_id` (set by `moderate_agency_internal`).
