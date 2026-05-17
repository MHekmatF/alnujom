# Quickstart: Currencies & Exchange Rates

**Audience**: an engineer or reviewer validating Phase 9 against the remote Supabase project + the Flutter app on the reference Infinix Note 8.
**Prerequisites**:
- Phases 1-8 are merged. The remote Supabase project is up to date with Phase 8.
- The Flutter app builds and runs against the remote project per the `.env.json` configured in `project_dart_defines.md`.
- You have admin credentials (a user holding the `admin` or `super_admin` role; both include `currencies.manage` per Phase 6 §9.1).
- You have a moderator account (Phase 6 `moderator` role — does NOT include `currencies.manage`).

This recipe walks the **12 steps** that exercise every FR and SC. It uses Supabase MCP `apply_migration`, `execute_sql`, `get_advisors`, and `list_tables` plus manual UI walks on the device. **No automated tests run** per the project-wide no-new-tests directive.

---

## Step 1 — Apply the five Phase 9 migrations

Apply each migration via Supabase MCP `apply_migration` in order:

1. `20260518120001_create_currencies.sql`
2. `20260518120002_create_exchange_rates.sql`
3. `20260518120003_create_update_exchange_rate_rpc.sql`
4. `20260518120004_alter_user_preferences_fk.sql`
5. `20260518120005_phase9_advisor_hardening.sql`

After each migration, run `list_migrations` and confirm the new entry appears. The migrations are idempotent — re-applying is safe per the project memory `project_supabase_mcp_apply_migration.md`, but produces a duplicate tracker row (verify SQL idempotency by reading the file).

**Verification per migration**:

```sql
-- After migration 1:
SELECT count(*) FROM public.currencies;
-- Expected: 2 (SC-001)

SELECT code, name_ar, name_en, symbol, display_decimals, is_system, is_active, sort_order
FROM public.currencies ORDER BY sort_order;
-- Expected: SYP (sort_order=10) then USD (sort_order=20), both is_system=true

-- After migration 2:
SELECT count(*) FROM public.exchange_rates;
-- Expected: 0 or 2 — if FR-005 starter rate seeded, 2 rows (USD→SYP admin + SYP→USD auto-derived). (SC-002)

-- After migration 3:
SELECT proname FROM pg_proc WHERE proname = 'update_exchange_rate' AND pronamespace = 'public'::regnamespace;
-- Expected: 1 row

-- After migration 4:
SELECT conname FROM pg_constraint WHERE conname = 'user_preferences_display_currency_fkey';
-- Expected: 1 row (SC-022)

-- After migration 5:
-- Run get_advisors and confirm zero warnings about RLS-disabled tables, missing GRANT/REVOKE, or insecure SECURITY DEFINER functions.
```

---

## Step 2 — Confirm anonymous SELECT works (SC-004)

Switch to the `anon` role and SELECT from both tables:

```sql
SET ROLE anon;
SELECT count(*) FROM public.currencies;
-- Expected: 2 (no permission error)
SELECT count(*) FROM public.exchange_rates;
-- Expected: 0 or 2 (no permission error)

-- Attempted INSERT denied
INSERT INTO public.currencies (code, name_ar, name_en, symbol) VALUES ('XYZ', 'x', 'x', 'x');
-- Expected: ERROR row-level security violation

RESET ROLE;
```

---

## Step 3 — Confirm immutability trigger refuses system-row deletion (SC-017)

```sql
-- (as postgres or as an admin with currencies.manage)
DELETE FROM public.currencies WHERE code = 'USD';
-- Expected: ERROR 42501: cannot delete system currency USD

UPDATE public.currencies SET code = 'usdv2' WHERE code = 'USD';
-- Expected: ERROR 42501: cannot rename system currency code (USD → usdv2)

-- Other column updates ARE allowed
UPDATE public.currencies SET symbol = '$$' WHERE code = 'USD';
-- Expected: UPDATE 1
UPDATE public.currencies SET symbol = '$' WHERE code = 'USD';  -- restore
```

---

## Step 4 — Confirm audit triggers emitted seed rows (SC-015 / US8 acceptance scenario 6)

```sql
SELECT action, count(*) FROM public.audit_logs
WHERE actor_user_id IS NULL AND target_type IN ('currencies', 'exchange_rates')
GROUP BY action ORDER BY action;
-- Expected:
--   currency.created  | 2
--   exchange_rate.updated | 2  (if FR-005 starter rate seeded)
```

---

## Step 5 — Call `update_exchange_rate` RPC from the device (US3 + SC-005 + SC-008a)

Stopwatched flow on the Infinix Note 8:

1. Sign in as the Phase 5 admin.
2. Open the admin home — confirm the **Currencies** tile is visible (SC-009 / US2 acceptance scenario 2).
3. Tap "Currencies" — confirm `CurrenciesListPage` renders (with the seeded USD + SYP rows and a "1 USD = 15,000 SYP" subline on USD if FR-005 starter is in place).
4. Tap "Set new rate" — confirm `SetExchangeRatePage` opens.
5. Pick base = USD, target = SYP, enter rate = 16000, leave effective_at at default, leave source blank.
6. Observe the live derived-rate preview line update as you type: "1 SYP = 0.0000625 USD" (FR-016 transparency).
7. Tap Submit.
8. Confirm the page navigates back to `CurrenciesListPage` with the new rate visible. **Total elapsed time ≤ 60 seconds** (SC-005).

From a desktop, verify the two rows landed:

```sql
SELECT base_currency, target_currency, rate, source FROM public.exchange_rates
WHERE created_at > now() - interval '5 minutes'
ORDER BY created_at DESC;
-- Expected: 2 rows (USD→SYP rate=16000 source=NULL; SYP→USD rate=0.0000625 source='auto-derived from <uuid>')

SELECT count(*) FROM public.audit_logs
WHERE action = 'exchange_rate.updated' AND created_at > now() - interval '5 minutes';
-- Expected: 2 (SC-008a)
```

---

## Step 6 — Confirm the symmetric 24-hour gate (SC-025 / Q5)

Re-open `SetExchangeRatePage`:

1. Pick base = USD, target = SYP, rate = 17000.
2. Change `effective_at` to **48 hours from now**. Tap Submit.
3. Confirm `unusual_timing_confirmation_dialog.dart` renders with the **future-dating** copy ("future-date").
4. Cancel. Now change `effective_at` to **48 hours in the past**. Tap Submit.
5. Confirm the same dialog widget renders with the **backdating** copy ("back-date").
6. Confirm both dialogs differ only in timing-direction wording (FR-017 / Q5).

---

## Step 7 — Test the preferred-currency toggle (US4 + SC-012)

1. Open the profile/settings page on the device.
2. Confirm the **Preferred currency** toggle is visible with two options ("ليرة سورية" / "دولار أمريكي" in `ar` locale).
3. Confirm the current selection matches:

   ```sql
   SELECT display_currency FROM public.user_preferences WHERE user_id = '<this user>';
   ```

4. Tap "US Dollar" (Arabic: "دولار أمريكي"). Re-query — confirm the value is now `'USD'`.
5. Toggle back. Confirm the value is now `'SYP'`.

---

## Step 8 — Test the 10 `MoneyFormatter` golden cases (SC-013 / US7)

Open the dev-only `MoneyFormatterShowcasePage` at `/debug/money-formatter` on the device (R-21).

Each row of the showcase renders a `{amount, currency}` input plus the expected output string in both `ar` and `en` locales. Walk through each and confirm the rendered string matches the locked expected output.

| # | Input | Expected `ar` | Expected `en` |
|---|---|---|---|
| 1 | `{amount: 750000000, currency: SYP}` | `٧٥٠٬٠٠٠٬٠٠٠ ل.س` | `750,000,000 SYP` |
| 2 | `{amount: 50000, currency: USD}` | `٥٠٬٠٠٠ $` | `$50,000` |
| 3 | `{amount: 1234567.89, currency: USD}` | `١٬٢٣٤٬٥٦٧٫٨٩ $` | `$1,234,567.89` |
| 4 | `{amount: 0, currency: SYP}` | `٠ ل.س` | `0 SYP` |
| 5 | `{amount: 0, currency: USD}` | `٠٫٠٠ $` | `$0.00` |
| 6 | `{amount: 1, currency: SYP}` | `١ ل.س` | `1 SYP` |
| 7 | `{amount: 49999.997, currency: USD}` (banker's rounding to 2 decimals) | `٥٠٬٠٠٠٫٠٠ $` | `$50,000.00` |
| 8 | `{amount: 49999.995, currency: USD}` (half-to-even → .00) | `٤٩٬٩٩٩٫٩٩ $`* | `$49,999.99`* |
| 9 | `{amount: -50, currency: USD}` (admin context) | `‎-٥٠ $`† | `-$50` |
| 10 | `{amount: 15000.5, currency: SYP}` (display_decimals=0 truncates `.5` to `16000` via banker's round to even integer) | `١٦٬٠٠٠ ل.س`‡ | `16,000 SYP`‡ |

\* Cases 8 + 10 verify banker's rounding behavior (half-to-even). For 49999.995 → 49999.99 (the .99 is even) instead of 50000.00. For 15000.5 → 16000 (16 is even) instead of 15001 (odd).
† Arabic minus-sign placement: implementation may bidi-mark the minus; the rendered visual is "‎-50 $" with the minus immediately before the digits.
‡ SYP `display_decimals=0` discards fractional digits at format time.

If any cell renders differently, file a bug — the formatter is deterministic, so a mismatch is reproducible.

---

## Step 9 — Confirm route guard refuses non-permission-holder (SC-010)

1. Sign out the admin. Sign in as the moderator account.
2. Open the admin home — confirm the **Currencies** tile is **absent**.
3. Hand-type `/admin/currencies` as a deep-link. Confirm the route guard redirects to the unauthorized destination (the established admin-route-unauthorized pattern from Phase 5/6).
4. Try the other three routes (`/admin/currencies/set-rate`, `/admin/currencies/USD/history`, `/admin/currencies/form?mode=create`) — confirm all are refused.

---

## Step 10 — Confirm RLS deny on direct writes (SC-011)

From the desktop, set a JWT for the moderator account and attempt direct writes:

```sql
-- (with moderator JWT)
INSERT INTO public.currencies (code, name_ar, name_en, symbol) VALUES ('EUR', 'يورو', 'Euro', '€');
-- Expected: 0 rows affected (RLS deny)

INSERT INTO public.exchange_rates (base_currency, target_currency, rate) VALUES ('USD', 'SYP', 99999);
-- Expected: 0 rows affected (RLS deny)

SELECT public.update_exchange_rate('USD', 'SYP', 99999);
-- Expected: ERROR 42501: permission denied: currencies.manage required
```

---

## Step 11 — Confirm exchange-rate history view (US6)

Sign back in as the admin. Set 2-3 rates over time via `SetExchangeRatePage`. Open `ExchangeRateHistoryPage` for USD (`/admin/currencies/USD/history`).

- Confirm rows ordered by `effective_at DESC`.
- Confirm each row shows: target_currency, rate, effective_at, set_by (admin's display name), source (or `—`).
- Confirm the auto-derived inverse rows display the **derived badge** (per US6 acceptance scenario 3).
- Apply the "target currency = SYP" filter — confirm only USD → SYP rows remain.
- Tap "Set new rate" CTA in the header — confirm `SetExchangeRatePage` opens pre-filled with `base_currency = USD`.

---

## Step 12 — Cross-device propagation + currency deactivation (SC-021 + US4 acceptance scenario 4)

1. On device A, sign in as the admin. Open `CurrencyFormPage` for SYP. Deactivate it (`is_active = false`). Save.
2. On device B (already signed in as a regular user with `display_currency='SYP'`), open the profile/settings page.
3. Confirm the toggle's currently-selected option falls back to USD (the next active currency by `sort_order ASC`) and persists the fallback to `user_preferences.display_currency='USD'`.
4. On device A, reactivate SYP. On device B, the toggle re-offers SYP on next mount but does NOT auto-revert the user's choice (the fallback was persisted).
5. Per Phase 6 FR-015 propagation, revoke `currencies.manage` from the admin via Phase 7's `RoleEditorPage`. On device A's next foreground resume, the **Currencies** tile disappears (SC-021).

---

## Per-FR / per-SC verification map

| FR / SC | Verified in step |
|---|---|
| FR-001/002 (currencies schema) | Step 1 |
| FR-003 (exchange_rates schema) | Step 1 |
| FR-004 (seed of USD + SYP) | Step 1 |
| FR-005 (optional starter rate) | Step 1 |
| FR-006 (FK shape) | Step 1 |
| FR-007 (audit triggers) | Step 4 |
| FR-007a (immutability trigger) | Step 3 |
| FR-008 (insert-only on exchange_rates) | Step 10 |
| FR-009 (anon SELECT) | Step 2 |
| FR-010 (no new permission keys) | (review — no code change to permission_keys.dart) |
| FR-011 (PermissionChecker cache refresh) | Step 12 |
| FR-012 (update_exchange_rate RPC) | Step 5 + Step 10 |
| FR-013 (admin tile) | Step 5 + Step 9 |
| FR-014 (route guard) | Step 9 |
| FR-015 (admin pages) | Step 5 + Step 11 |
| FR-015a (system-row affordance hiding) | Step 3 (UI walk parallel) |
| FR-016 (form validation + derived-rate preview) | Step 5 |
| FR-017 (symmetric 24h gate) | Step 6 |
| FR-018 (preferred-currency toggle) | Step 7 |
| FR-019 (user_preferences FK) | Step 1 |
| FR-019a (row-selection rule) | (deferred to Phase 10 ship time; the use case is unit-walked in isolation in Step 8) |
| FR-020/021/022/023 (Money + MoneyFormatter) | Step 8 |
| FR-024 (ARB keys) | (review) |
| FR-025 (design tokens) | (review) |
| FR-026 (audit row counts) | Steps 4 + 5 |
| SC-001 | Step 1 |
| SC-002 | Step 1 |
| SC-003 | Step 1 |
| SC-004 | Step 2 |
| SC-005 | Step 5 |
| SC-006 | (Phase 10 ship time) |
| SC-007 | Step 5 + Step 11 |
| SC-008 | Step 10 |
| SC-008a | Step 5 |
| SC-009 | Step 9 |
| SC-010 | Step 9 |
| SC-011 | Step 10 |
| SC-012 | Step 7 + (Phase 10 ship time) |
| SC-013 | Step 8 |
| SC-014 | (locale-toggle walk during Steps 5-11) |
| SC-015 | Steps 4 + 5 |
| SC-016 | Step 1 (idempotency re-apply) |
| SC-017 | Step 3 + (UI walk) |
| SC-018 | (review — no code change to permission_keys.dart) |
| SC-019 | (review) |
| SC-020 | (review — Phase 3 lint guard at PR time) |
| SC-021 | Step 12 |
| SC-022 | Step 1 |
| SC-023 | Step 8 (formatter signature inspection) |
| SC-024 | (deferred to Phase 10 ship time) |
| SC-025 | Step 6 |

---

## Reverting Phase 9

If a defect is discovered during Phase 9 implementation that requires reverting:

```sql
-- Detach FK on user_preferences
ALTER TABLE public.user_preferences DROP CONSTRAINT IF EXISTS user_preferences_display_currency_fkey;

-- Drop the RPC
DROP FUNCTION IF EXISTS public.update_exchange_rate(TEXT, TEXT, NUMERIC, TIMESTAMPTZ, TEXT);

-- Drop the tables (CASCADE will remove triggers, policies, audit rows are retained)
DROP TABLE IF EXISTS public.exchange_rates;
DROP TABLE IF EXISTS public.currencies;

-- Drop the immutability trigger function
DROP FUNCTION IF EXISTS public.enforce_currency_system_immutability();
```

Note: dropping the tables retains the existing `audit_logs` rows referencing them — that is correct (audit history is sacrosanct). The Flutter side reverts by removing the new files and reverting the four updated existing files.
