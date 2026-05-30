# Contract — `public.submit_report` RPC

**Migration**: `supabase/migrations/20260530120006_create_submit_report_rpc.sql` (Sub-Phase D)

## Signature

```
public.submit_report(p_listing_id UUID, p_reason TEXT, p_note TEXT DEFAULT NULL)
  RETURNS UUID            -- the new report id
  SECURITY DEFINER  SET search_path = pg_catalog, public
  GRANT EXECUTE TO authenticated   (NOT anon)
```

## Behavior

1. `auth_required` (ERRCODE `28000`) if `auth.uid()` is null (FR-010(a)).
2. `invalid_reason` (`22023`) if `p_reason` ∉ the 8 canonical reasons.
3. Listing validity (Q6=A / FR-010(b)): `listing_not_found` (`23503`) if the listing does not exist; `listing_not_approved` (`23514`) if `status <> 'approved'`.
4. Open-report dedup (FR-004): `already_reported` (`23505`) if the caller has a `new`/`reviewing` report on the listing. The `ux_reports_open_per_reporter_listing` partial unique index is the race-safe backstop.
5. Insert `reports` row with `reporter_user_id := auth.uid()`, `status := 'new'`, `note := NULLIF(p_note,'')`, and `metadata := jsonb_build_object('ip', inet_client_addr()::text, 'user_agent', current_setting('request.headers', true)::jsonb->>'user-agent')` (FR-010(e), mirrors `record_lead_event`). Return the new id.

## Client mapping (Flutter)

`supabase.rpc('submit_report', params: {'p_listing_id': listingId, 'p_reason': reason.wireValue, 'p_note': note})`. The data source maps the PG error codes to `Failure`s; the cubit surfaces `already_reported` as the localized "already reported" acknowledgement (FR-004) and others as a retryable error (FR-005).

## Error codes

| Code | ERRCODE | Meaning |
|------|---------|---------|
| `auth_required` | 28000 | anonymous caller |
| `invalid_reason` | 22023 | reason not in the 8 |
| `listing_not_found` | 23503 | no such listing |
| `listing_not_approved` | 23514 | listing not `approved` |
| `already_reported` | 23505 | open report already exists |

## Smoke tests

1. Authenticated submit on an approved listing → returns a UUID; one `reports` row.
2. Anonymous `rpc('submit_report', …)` → `auth_required`.
3. Submit on a `draft`/non-existent listing → `listing_not_approved` / `listing_not_found`.
4. Second submit while open → `already_reported`; no second row.
5. No direct client INSERT grant on `public.reports` exists (forged `reporter_user_id` impossible).
