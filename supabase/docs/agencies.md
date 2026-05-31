# agencies

## Purpose

`public.agencies` is the Phase 19 brokerage store. Each row is one agency owned
by exactly **one** approved publisher (the `owner_user_id` UNIQUE + the
`already_owns_agency` guard in `create_agency`). The public agency directory and
the verified-agency listing badge only ever surface a row whose
`status = 'approved'`; the owner and active members see their own agency at any
status; a holder of the `agencies.view` permission sees all (FR-001, FR-003,
FR-011, FR-025).

Authoritative interface contract:
[`specs/019-agencies/contracts/phase19-agencies-table.md`](../../specs/019-agencies/contracts/phase19-agencies-table.md).

## Shape

Defined in `supabase/migrations/20260531120001_create_agencies_table.sql`. Direct
client writes are blocked at the table level (Migration …005 revokes
INSERT/UPDATE/DELETE) so every row originates from the `create_agency` SECURITY
DEFINER RPC (Migration …008), and every status transition flows through the
service-role `moderate_agency_internal` RPC (Migration …010).

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | `uuid` | PK, DEFAULT `gen_random_uuid()` | Agency identifier. |
| `owner_user_id` | `uuid` | NOT NULL, **UNIQUE**, FK -> `auth.users(id)` ON DELETE CASCADE | One agency per owner (Q3=A / R-138). Un-forgeable: set by `create_agency` from `auth.uid()`. |
| `name` | `text` | NOT NULL, CHECK `length(trim(name)) > 0` | Display name. Unique **among approved agencies only** — see forward-stated rule below. |
| `description` | `text` | NULL | Public profile field. |
| `phone` | `text` | NULL | Public profile field. |
| `whatsapp` | `text` | NULL | Public profile field. |
| `address` | `text` | NULL | Public profile field. |
| `logo_path` | `text` | NULL | Path in the `agency-assets` bucket. |
| `cover_path` | `text` | NULL | Path in the `agency-assets` bucket. |
| `status` | `agency_status` | NOT NULL, DEFAULT `'pending'` | Lifecycle state (enum below). |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Server-generated. |
| `updated_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Maintained by the Phase 4 `set_updated_at` BEFORE-UPDATE trigger. |

## Enum: `agency_status`

`CREATE TYPE agency_status AS ENUM ('pending','approved','rejected','suspended')` —
new in this migration; NOT in `init_enums.sql`; distinct from
`account_approval_status` (which lacks `suspended`).

## Lifecycle

`pending → approved | rejected`; `approved ↔ suspended` (R-149). Transitions
happen ONLY via `moderate_agency_internal` (service-role, fired by the
`moderate_agency` Edge Function after a dual-layer permission check). A
suspension hides the public profile + badge but performs no mass listing change.

## Indices

| Index | Definition | Purpose |
|-------|-----------|---------|
| `idx_agencies_status` | `(status)` | Public directory + admin queue scans. |
| `ux_agencies_name_approved` | UNIQUE `(lower(name)) WHERE status = 'approved'` | Name-unique-among-approved backstop (forward-stated below; created in Migration …005). |

## FK delete behaviors (R-144)

| FK column | References | ON DELETE behavior | Rationale |
|-----------|-----------|-------------------|-----------|
| `owner_user_id` | `auth.users(id)` | **CASCADE** | Deleting the owning account removes the agency row (which in turn cascades `agency_members` + `agency_verification_requests`); a listing that referenced the agency has its `agency_id` SET NULL via the FK below. |
| `listings.agency_id` (FK lives on `listings`) | `public.agencies(id)` | **SET NULL** | `supabase/migrations/20260531120004_enforce_listings_agency_fk.sql`: a removed agency leaves its listings intact (they lose only the badge), never deleting listing rows (FR-018). |

## Name-unique-among-approved rule (forward-stated)

Per Q2-clarify, agency names are unique among **approved** agencies only;
duplicate `pending` names may coexist. This is enforced by the partial unique
index `ux_agencies_name_approved (lower(name)) WHERE status = 'approved'` created
in `supabase/migrations/20260531120005_create_agency_policies.sql` (Phase 3), and
by an `EXISTS` pre-check (`name_taken`, R-145 / FR-008) in
`moderate_agency_internal` on the `approve` action. Two approvals of the same
name racing past the pre-check are caught by the unique index on the second
commit — one approval wins, the other gets `name_taken`/409.

## RLS posture (forward-stated)

- **Migration 1 (this file)**: `ALTER TABLE public.agencies ENABLE ROW LEVEL
  SECURITY` is set. NO policies are attached. Default-deny means direct reads
  from any client session return zero rows until Migration …005 attaches the
  reader policies.
- **Migration …005 (`20260531120005_create_agency_policies.sql`)** will add:
  - `agencies_select_authenticated` — SELECT for `authenticated` where
    `status = 'approved' OR owner_user_id = auth.uid() OR
    public.is_agency_member(id) OR
    public.current_user_has_permission('agencies.view')`.
  - `agencies_select_anon` — SELECT for `anon` where `status = 'approved'` only
    (FR-032).
  - `REVOKE INSERT, UPDATE, DELETE ON public.agencies FROM authenticated, anon` —
    no client write path; creation via `create_agency`, transitions via
    `moderate_agency_internal` only.

The full live reader/writer matrix (data-model §1.14) is appended to this doc in
Sub-Phase C (T022). Reads in the app go through the SECURITY DEFINER `v_agencies`
view (Migration …006), which reproduces the public/owner/member/admin read
matrix in its WHERE clause and never projects the Vault ID/registration numbers.

## Live RLS reader/writer matrix (Sub-Phase C, Migration …005)

Attached by `supabase/migrations/20260531120005_create_agency_policies.sql`. This
is the load-bearing reader/writer matrix (Principle III, data-model §1.14):

| Actor | `agencies` SELECT | `agency_members` SELECT | `agency_verification_requests` SELECT | any table INSERT/UPDATE/DELETE | Vault id/registration |
|-------|-------------------|--------------------------|----------------------------------------|--------------------------------|------------------------|
| Anonymous | ✅ only `status='approved'` | ❌ | ❌ | ❌ | ❌ |
| Authenticated non-member | ✅ approved only | ✅ own invitation row only | ❌ | ❌ (RPC only) | ❌ |
| Owner / active member | ✅ own agency (any status) | ✅ own agency roster | agency-admins ✅ / agents ❌ | ❌ (RPC only) | ❌ (admin-decrypt only) |
| `agencies.view`/`approve`/`suspend` holder | ✅ ALL | ✅ ALL | ✅ ALL | ❌ (moderate_agency → service-role RPC only) | ✅ via `app_vault_secret_for_agency` |
| `service_role` (Edge Fn) | n/a (bypasses RLS) | n/a | n/a | via `moderate_agency_internal` only | n/a |

`agencies` policies (Migration …005):

- `agencies_select_authenticated` — `TO authenticated USING (status='approved' OR
  owner_user_id=auth.uid() OR public.is_agency_member(id) OR
  public.current_user_has_permission('agencies.view'))`.
- `agencies_select_anon` — `TO anon USING (status='approved')` (FR-032).
- `REVOKE INSERT, UPDATE, DELETE ON public.agencies FROM authenticated, anon` —
  no client write; creation via `create_agency`, transitions via
  `moderate_agency_internal` only.

## `v_agencies` definer-view scoping (Migration …006)

`public.v_agencies` (`supabase/migrations/20260531120006_create_v_agencies_view.sql`)
is a **SECURITY DEFINER** view (no `security_invoker` set ⇒ definer default). Its
explicit `WHERE status='approved' OR owner_user_id=auth.uid() OR
public.is_agency_member(id) OR public.current_user_has_permission('agencies.view')`
reproduces the public/owner/member/admin matrix above, so a member's own `pending`
agency stays visible (an invoker view would re-apply the `agencies` RLS and hide it
— the Phase 18 `20260530120010` gotcha, memory `project_supabase_view_rls_gotchas`).
`auth.uid()` / `current_user_has_permission()` still resolve to the CALLER inside a
definer view (they read the request JWT), so cross-user isolation (SC-009) is
preserved by the WHERE. `GRANT SELECT TO anon, authenticated` (anon sees only
`approved` rows because the member/permission predicates are false for anon). The
view projects the public profile fields ONLY — never the Vault id/registration
numbers. The `v_listings_public` badge amendment (same migration) LEFT JOINs
`agencies … AND status='approved'`, so only approved-agency listings carry the
`agency_id`/`agency_name`/`agency_logo_path` badge fields (others get NULLs, no reflow).

## Audit triggers (Migration …011)

`supabase/migrations/20260531120011_create_agency_audit_triggers.sql` attaches
`trg_agencies_audit_status` — `AFTER UPDATE OF status … WHEN (OLD.status IS
DISTINCT FROM NEW.status) EXECUTE FUNCTION log_audit('agency.status_changed',
'status', 'id')` — reusing the Phase 4 `log_audit()` emitter (FR-012/FR-041). The
actor is read from `app.current_user_id` (set by `moderate_agency_internal`).
