# Contract — Agency RLS policies + `v_agencies` view + `v_listings_public` badge amendment

**Files**: `supabase/migrations/20260531120005_create_agency_policies.sql` + `…006_create_v_agencies_view.sql` (Sub-Phase C). Full SQL in `data-model.md §1.5–§1.6`. This is the load-bearing reader/writer matrix (Principle III).

## RLS policies (SELECT only; all writes REVOKE-d)

| Table | SELECT `USING` | Writes |
|-------|----------------|--------|
| `agencies` (authenticated) | `status='approved' OR owner_user_id=auth.uid() OR is_agency_member(id) OR current_user_has_permission('agencies.view')` | REVOKE INSERT/UPDATE/DELETE |
| `agencies` (anon) | `status='approved'` | — |
| `agency_members` | `user_id=auth.uid() OR is_agency_member(agency_id) OR current_user_has_permission('agencies.view')` | REVOKE |
| `agency_verification_requests` | `is_agency_admin(agency_id) OR current_user_has_permission('agencies.view')` | REVOKE |

Name uniqueness: `ux_agencies_name_approved (lower(name)) WHERE status='approved'` (R-145).

## `v_agencies` view (SECURITY DEFINER)

- Projects the agency PUBLIC profile fields only (NEVER the Vault id/registration numbers).
- `WHERE status='approved' OR owner_user_id=auth.uid() OR is_agency_member(id) OR current_user_has_permission('agencies.view')` — reproduces the public/owner/member/admin matrix. DEFINER is required so a member's own `pending` agency stays visible (an invoker view would re-apply the agencies RLS and hide it — the Phase 18 `20260530120010` gotcha, memory `project_supabase_view_rls_gotchas`).
- `GRANT SELECT TO anon, authenticated` (anon sees only `approved` rows because the membership/permission predicates are false for anon).

## `v_listings_public` badge amendment (additive)

- Adds `LEFT JOIN public.agencies ag ON ag.id=l.agency_id AND ag.status='approved'` projecting `agency_id`/`agency_name`/`agency_logo_path`. Preserves the existing projection + `WHERE status='approved'` + the existing `security_invoker` setting. Only approved-agency listings carry the badge fields; others get NULLs.

## Smoke tests (SC-009)

1. Anon `select * from v_agencies` → only `approved` rows; zero member/verification rows.
2. Owner of a `pending` agency → sees their own agency via `v_agencies`; an unrelated authenticated user does not.
3. Non-`agencies.view` authenticated → cannot read another agency's roster or any verification request.
4. `select agency_name from v_listings_public where agency_id is not null` returns the name only for approved agencies.
