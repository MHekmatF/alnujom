# Contract: Phase 9 RLS Policies

**Owner**: Phase 9, migrations 1 + 2 (inline) + `supabase/policies/currencies_phase9.sql` + `supabase/policies/exchange_rates_phase9.sql` (mirror files per R-02).
**Consumers**: every Flutter feature consuming the catalog; every Phase 13/14/15 anonymous read path.

## Obligations

### `public.currencies`

| Verb | Roles | Predicate |
|---|---|---|
| SELECT | `anon`, `authenticated` | `USING (true)` |
| INSERT | `authenticated` | `WITH CHECK (current_user_has_permission('currencies.manage'))` |
| UPDATE | `authenticated` | `USING (current_user_has_permission('currencies.manage')) WITH CHECK (current_user_has_permission('currencies.manage'))` |
| DELETE | `authenticated` | `USING (current_user_has_permission('currencies.manage'))` |

### `public.exchange_rates`

| Verb | Roles | Predicate |
|---|---|---|
| SELECT | `anon`, `authenticated` | `USING (true)` |
| INSERT | `authenticated` | `WITH CHECK (current_user_has_permission('currencies.manage'))` |
| UPDATE | `authenticated` | `USING (false)` — append-only invariant (R-08) |
| DELETE | `authenticated` | `USING (false)` — append-only invariant |

**Anonymous read carve-out**: Per R-04, the SELECT policies on both tables admit `anon`. This is the third project-wide carve-out from the authenticated-only default. The migration comment documents this per Constitution III's "explicit documentation when a table opts out" requirement (R-16).

**Phase 4/5/6/7/8 policy files**: NOT edited. Phase 9 introduces new policy files alongside, never modifies existing ones (carry-forward invariant from Phase 4 R-02).

## Verification

```sql
-- All policies present on currencies
SELECT policyname, cmd, roles FROM pg_policies WHERE schemaname='public' AND tablename='currencies' ORDER BY policyname;
-- Expected: 4 rows (currencies_select, currencies_insert, currencies_update, currencies_delete)

-- All policies present on exchange_rates
SELECT policyname, cmd, roles, qual FROM pg_policies WHERE schemaname='public' AND tablename='exchange_rates' ORDER BY policyname;
-- Expected: 4 rows (exchange_rates_select, exchange_rates_insert, exchange_rates_deny_update, exchange_rates_deny_delete)
-- The deny_update and deny_delete policies show qual='false'

-- Anonymous SELECT works
SET ROLE anon;
SELECT count(*) FROM public.currencies;
-- Expected: 2 (without error)
SELECT count(*) FROM public.exchange_rates;
-- Expected: 0 or 2 (no error)
RESET ROLE;

-- Anonymous INSERT denied
SET ROLE anon;
INSERT INTO public.currencies (code, name_ar, name_en, symbol) VALUES ('XYZ', 'x', 'x', 'x');
-- Expected: ERROR row-level security violation OR 0 rows affected
RESET ROLE;

-- UPDATE on exchange_rates always denied even for currencies.manage holders
-- (Set a session JWT for an admin holding currencies.manage, then:)
UPDATE public.exchange_rates SET rate = 99999 WHERE id = (SELECT id FROM public.exchange_rates LIMIT 1);
-- Expected: 0 rows affected (the policy `WITH CHECK (false)` denies)
```

## Forbidden

- Adding a UPDATE or DELETE policy to `exchange_rates` with a non-`false` predicate. The append-only invariant is a hard contract.
- Removing the `anon` role from SELECT policies (Phase 13/14 anonymous read paths would break).
- Changing `current_user_has_permission('currencies.manage')` to any other permission key (FR-010 no-new-keys invariant).
