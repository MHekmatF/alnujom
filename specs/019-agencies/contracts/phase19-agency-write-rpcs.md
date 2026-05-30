# Contract — Agency write RPCs + Vault helpers

**Files**: `supabase/migrations/20260531120007_create_agency_vault_helpers.sql` + `…008_create_agency_write_rpcs.sql` (Sub-Phases D). Full SQL in `data-model.md §1.7–§1.8`. All `SECURITY DEFINER SET search_path`, granted to `authenticated`, each self-gating; the three tables have NO client write grant.

## Vault helpers (R-141 / ADR-0001)

- `app_vault_set_agency_secret(p_agency_id uuid, field_name text, p_value text) → void` — self-gates `is_agency_admin`; `field_name ∈ {id_document_number, commercial_registration_number}`; `vault.create_secret(value, 'pii.agency.{agency_id}.{field}', …)`.
- `app_vault_secret_for_agency(p_agency_id uuid, field_name text) → text` — returns NULL unless `current_user_has_permission('agencies.view')`; admin-decrypt only.

## Write RPCs

| RPC | Auth gate | Behavior | Error codes |
|-----|-----------|----------|-------------|
| `create_agency(name, description?, phone?, whatsapp?, address?) → uuid` | `auth.uid()` + approved publisher | INSERT `agencies` (`pending`, owner=auth.uid()) + owner `agency_members` (`admin`/`active`) | `auth_required`(28000), `not_a_publisher`(42501), `already_owns_agency`(23505), `invalid_name`(22023) |
| `invite_agency_member(agency_id, phone, role='agent') → uuid` | `is_agency_admin(agency_id)` | resolve phone→user; INSERT `agency_members` `pending` `ON CONFLICT DO NOTHING` | `permission_denied`(42501), `invalid_role`(22023), `user_not_found`(23503) |
| `respond_agency_invitation(agency_id, accept) → void` | invitee = `auth.uid()` | flip own `pending` row → `active`/`removed` | `no_pending_invitation`(P0002) |
| `set_agency_member_role(agency_id, user_id, role) → void` | `is_agency_admin` | UPDATE `member_role` (owner protected) | `permission_denied`, `invalid_role`, `cannot_modify_owner` |
| `remove_agency_member(agency_id, user_id) → void` | `is_agency_admin` | set `status='removed'` (owner protected) | `permission_denied`, `cannot_remove_owner` |
| `submit_agency_verification(agency_id, id_document_number, registration_number, evidence_urls?) → uuid` | `is_agency_admin` | INSERT `agency_verification_requests` `pending` + Vault-store the two numbers | `permission_denied`, `23505` (open request exists) |

## Smoke tests

1. Non-publisher `create_agency` → `not_a_publisher`; second agency by an owner → `already_owns_agency`.
2. `invite_agency_member` with an unregistered phone → `user_not_found`, no row; with a registered phone → `pending` row; re-invite → idempotent.
3. `respond_agency_invitation(accept=true)` by the invitee → `active`; by a non-invitee → `no_pending_invitation`.
4. `set_agency_member_role`/`remove_agency_member` by an `agent` → `permission_denied`; targeting the owner → `cannot_modify_owner`/`cannot_remove_owner`.
5. `submit_agency_verification` → request row; `app_vault_secret_for_agency` returns the number for an `agencies.view` holder and NULL otherwise (SC-010).
