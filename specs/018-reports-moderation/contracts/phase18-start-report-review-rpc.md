# Contract — `public.start_report_review` RPC (advisory soft claim)

**Migration**: `supabase/migrations/20260530120007_create_resolve_report_rpcs.sql` (Sub-Phase E). Implements Q4=B.

## Signature

```
public.start_report_review(p_report_id UUID) RETURNS VOID
  SECURITY DEFINER  SET search_path = public, pg_temp
  GRANT EXECUTE TO authenticated   (self-gates on reports.manage internally)
```

## Behavior

1. Self-gate: `IF NOT public.current_user_has_permission('reports.manage') THEN RAISE EXCEPTION 'permission_denied' (42501)`.
2. `UPDATE public.reports SET status='reviewing', reviewing_by = auth.uid(), reviewing_started_at = now() WHERE id = p_report_id AND status = 'new'`.

## Soft-lock semantics (FR-036)

- The `WHERE status='new'` guard means claiming an already-`reviewing` report is a **no-op** — it does NOT steal the claim or error.
- The claim is **advisory and overridable**: the admin UI surfaces the current `reviewing_by` ("being reviewed by …") but still allows any `reports.manage` holder to take over or resolve directly. There is NO hard lock.
- Resolution (`resolve_report_internal`) is valid from EITHER `new` or `reviewing`, so the claim is optional workflow signposting, never a precondition.

## Client mapping

`supabase.rpc('start_report_review', params: {'p_report_id': reportId})` from the admin data source (`G`). The admin "Start review" button calls it; the queue/detail then reflects `reviewing` + the reviewer.

## Smoke tests

1. `reports.manage` caller on a `new` report → status `reviewing`, `reviewing_by` set.
2. Non-`reports.manage` caller → `permission_denied`.
3. Call on an already-`reviewing` report → no-op (still resolvable by the same or another admin).
