# Contract — Reports & Moderation RLS policies

**Migration**: `supabase/migrations/20260530120003_create_reports_policies.sql` (Sub-Phase C)

## `public.reports`

- **SELECT** `reports_select_self_or_admin` (TO `authenticated`): `USING (reporter_user_id = auth.uid() OR public.current_user_has_permission('reports.manage'))`.
- **INSERT / UPDATE / DELETE**: none granted. `REVOKE INSERT, UPDATE, DELETE … FROM authenticated, anon`. Creation via `submit_report` (SECURITY DEFINER); resolution/claim via `resolve_report_internal` / `start_report_review`.
- **anon**: no policy ⇒ all anon access denied.

## `public.moderation_actions`

- **SELECT** `moderation_actions_select_admin` (TO `authenticated`): `USING (public.current_user_has_permission('reports.manage'))`.
- **INSERT / UPDATE / DELETE**: none granted (REVOKE-d). Written only by `resolve_report_internal`.
- **anon**: no policy ⇒ denied.

## Reader/writer matrix (the load-bearing test surface — SC-009)

| Actor | reports read | reports write | moderation_actions read | moderation_actions write |
|-------|--------------|---------------|--------------------------|--------------------------|
| Anonymous | ❌ | ❌ | ❌ | ❌ |
| Reporter | own only | ❌ | ❌ | ❌ |
| Non-admin authenticated | own only | ❌ | ❌ | ❌ |
| `reports.manage` | ALL | ❌ (RPC/Edge only) | ALL | ❌ (RPC only) |

## Smoke tests

1. user-A SELECTs `reports` with forged `WHERE reporter_user_id = '<user-B>'` → zero rows.
2. anon SELECT `reports` / `moderation_actions` → zero rows / denied.
3. non-admin SELECT `moderation_actions` → zero rows.
4. `reports.manage` SELECT `reports` → all rows.
5. Any client `INSERT INTO public.reports …` → rejected (no grant).
6. Any client `UPDATE public.reports SET status='resolved' …` → rejected (no grant).
7. No `favorites.view_all`-style or publisher path exists (FR-028).
