# Contract: `public.submit_listing(p_listing_id UUID) RETURNS JSONB`

**Owner**: Phase 10, migration `20260519120007_create_submit_listing_rpc.sql`.
**Consumers**: `lib/features/listing_form/domain/usecases/submit_listing.dart` → `lib/features/listing_form/data/datasources/supabase_listings_datasource.dart` (`supabase.rpc('submit_listing', ...)`); Phase 12 will reuse the audit + history side-effects (without calling this RPC directly — Phase 12 has its own approve/reject RPCs).

## Obligations

Per R-06, `submit_listing` is a SECURITY DEFINER PL/pgSQL function — NOT a TypeScript Edge Function. The full body is in [data-model.md § RPC](../data-model.md). The function MUST:

1. **Load** the listing row by `p_listing_id`; RAISE `42704 undefined_object` if not found.
2. **Verify ownership**: `auth.uid() = listing.publisher_user_id`; RAISE `42501 insufficient_privilege` on mismatch.
3. **Verify approved-pair**: `profiles.publisher_status='approved' AND profiles.account_status='approved'`; RAISE `42501` on failure.
4. **Verify editable status**: `listing.status IN ('draft', 'rejected')`; RAISE `22023 invalid_parameter_value` on mismatch.
5. **Re-run the Q1 Full required-field validation per FR-010a**: always-required set (title, purpose, property_type, governorate_id, city_id, area_id, address_text, area_size, phone-or-whatsapp, exactly one `is_primary=true` `listing_prices` row with `amount>0`); conditionally-required when `property_type IN ('apartment','villa')`: rooms, bathrooms. On missing fields, RAISE `22023` with `DETAIL` carrying `jsonb_build_object('missing_fields', to_jsonb(v_missing))::text`.
6. **Flip status**: `UPDATE public.listings SET status='pending_review' WHERE id=p_listing_id`. The status-transition trigger appends the history row; the audit-trigger emits `listing.updated` + `listing.submitted`.
7. **Return** `jsonb_build_object('listing_id', p_listing_id, 'status', 'pending_review', 'submitted_at', now())`.

The function is `SECURITY DEFINER` with `search_path=public, auth`. EXECUTE is REVOKEd from `PUBLIC, anon` and GRANTed to `authenticated`.

## SQLSTATE ↔ HTTP error mapping

| SQLSTATE | Meaning | HTTP-equivalent | Client display |
|---|---|---|---|
| `42704` | undefined_object — listing not found | 404 | localized "listing not found" |
| `42501` | insufficient_privilege — not the owner OR publisher not approved | 403 | localized "not authorized" |
| `22023` (with `missing_fields` DETAIL) | missing required fields | 400 | localized "missing required fields" + per-field breakdown |
| `22023` (without `missing_fields`) | listing not in editable status | 400 | localized "listing not editable" |
| any other | unhandled | 500 | localized generic error |

## Verification

```sql
-- Function exists with correct signature
SELECT proname, prosecdef, proconfig FROM pg_proc WHERE proname='submit_listing';
-- Expected: proname=submit_listing, prosecdef=t, proconfig includes search_path=public,auth

-- Permissions
SELECT grantee, privilege_type FROM information_schema.routine_privileges
WHERE routine_name='submit_listing';
-- Expected: only 'authenticated' has EXECUTE; 'anon' and 'PUBLIC' do NOT

-- Happy path
SELECT public.submit_listing('<draft_listing_id>'::uuid);
-- Expected: JSONB { listing_id, status='pending_review', submitted_at }
-- Also: SELECT status FROM public.listings WHERE id=<id> → 'pending_review'
-- Also: SELECT count(*) FROM public.listing_status_history WHERE listing_id=<id> → previous +1
-- Also: SELECT count(*) FROM public.audit_logs WHERE target_id=<id::text> AND action='listing.submitted' → 1

-- Missing-fields path
SELECT public.submit_listing('<incomplete_draft_id>'::uuid);
-- Expected: ERROR 22023 with DETAIL carrying jsonb { missing_fields: [...] }
```

## Forbidden

- Calling `log_audit()` directly from inside `submit_listing` (the trigger emits the audit row as a side-effect of the UPDATE).
- Adding new parameters (e.g., `p_reason`) — the submit action has no reason text; the rejected→pending_review flow re-submits without a reason.
- Bypassing the Q1 validation when called from an admin's JWT — admins use Phase 12's `approve_listing` / `reject_listing` RPCs, not `submit_listing`.
- Returning a row count instead of a structured JSONB.
- Implementing as a TypeScript Edge Function under `supabase/functions/submit_listing/` (R-06 deviation).
