---

description: "Task list for Phase 9 — Currencies & Exchange Rates. Each task is self-contained with exact absolute file paths and contract pointers so a cheaper LLM can implement without context-switching. Tasks are dependency-ordered: Setup → Foundational backend → Foundational Flutter data layer → US7 MoneyFormatter → US1 public-read verification → US2 admin tile + routes → US3 admin-set-rate → US4 preferred-currency toggle → US5 listing-render rule → US6 history page → US8 audit verification → Polish."

---

# Tasks: Currencies & Exchange Rates

**Input**: Design documents from `/specs/009-currencies/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/*.md`, `quickstart.md` — all complete and locked at Session 2026-05-17.

**Tests**: **NONE.** Per durable session feedback (`feedback_no_new_tests.md`), Phase 9 introduces ZERO new automated tests. Verification is manual SQL via Supabase MCP `execute_sql` + manual UI walks on the reference Infinix Note 8 device. The 10 `MoneyFormatter` golden cases from `quickstart.md` Step 8 are manually exercised on the debug-only `MoneyFormatterShowcasePage`, not automated. Existing Phase 1–8 tests remain unchanged.

**Organization**: Tasks are grouped by user story. Each story's checkpoint is a self-contained increment that can be demo'd without subsequent stories. Phase 9's plan-time ordering prioritizes shared infrastructure (Money value object, MoneyFormatter) in Foundational + US7 to unblock the admin-UI stories (US3, US6) that consume the formatter.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel with other [P]-marked tasks in the same phase (different files, no dependency on incomplete tasks).
- **[Story]**: User story label (US1..US8). Setup / Foundational / Polish tasks have NO story label.
- Every task includes the exact absolute file path and a pointer to the relevant contract / data-model section.

## Path Conventions

- Repository root: `H:\alnujom-project\`
- Supabase artifacts: `H:\alnujom-project\supabase\`
- Flutter sources: `H:\alnujom-project\lib\`
- ARB files: `H:\alnujom-project\lib\l10n\`

## Implementer briefing (read once before T001)

Before starting, read:

1. `H:\alnujom-project\specs\009-currencies\spec.md` — entire file (especially the Clarifications section's five Q&A, the eight user stories, and the 25 Success Criteria).
2. `H:\alnujom-project\specs\009-currencies\plan.md` — entire file (especially the Project Structure tree which lists every file you will touch, and Constitution Check which justifies every plan-time choice).
3. `H:\alnujom-project\specs\009-currencies\data-model.md` — entire file (full CREATE TABLE bodies, trigger function bodies, RLS policy bodies, RPC body, seed inventory, BLoC + entity shapes, ARB key inventory, per-FR / per-SC verification map).
4. `H:\alnujom-project\specs\009-currencies\quickstart.md` — Steps 1 through 4 first; you'll re-read individual steps when verification tasks reference them.
5. Skim the 13 contract files in `H:\alnujom-project\specs\009-currencies\contracts\` — these are the binding interface definitions. The most critical ones are `update-exchange-rate-rpc.md`, `money-value-object.md`, `money-formatter.md`, and `listing-price-row-selection.md`.
6. `H:\alnujom-project\specs\008-locations\tasks.md` — skim for format reference. Phase 9 follows the same pattern.

When a task says "per `contracts/<X>.md` § Y" or "per `data-model.md` § Z", that section is your source of truth for the exact code/SQL — copy it verbatim and adjust only the table/column names called out in the task.

**Two carry-forward project memories matter most**:

- `feedback_no_new_tests.md` — **do not write any new automated test files**. Manual verification only.
- `feedback_git_workflow.md` — commit + push immediately after each phase / each checkpoint marker (`⚠️ Checkpoint:` lines below). One PR per spec, opened only at end-of-spec.

---

## Phase 1: Setup

**Purpose**: Confirm environment + warm the toolchain. Add the one new package. No production code authored yet.

- [X] T001 Verify current git state. Run `git status` and `git branch --show-current` from `H:\alnujom-project`. Expected: branch `009-currencies`, working tree clean apart from the already-committed `specs/009-currencies/*` files. If branch is different, STOP and ask. If tree has unrelated dirty files, commit or stash before proceeding.

- [X] T002 [P] Verify Phase 8 is shipped on the remote Supabase project. Run via Supabase MCP `execute_sql` four checks: (a) `SELECT count(*) FROM public.governorates` returns `14`; (b) `SELECT count(*) FROM public.cities` returns between 30 and 40; (c) `SELECT count(*) FROM pg_proc WHERE proname='current_user_has_permission'` returns `1`; (d) `SELECT count(*) FROM public.permissions WHERE key='currencies.manage'` returns `1`. If any check fails, STOP — Phase 9 cannot proceed without Phase 8 + the existing `currencies.manage` permission row from Phase 6.

- [X] T003 [P] Verify `H:\alnujom-project\.env.json` exists and contains valid Supabase credentials (URL + anon key + service_role key per project memory `project_dart_defines.md`). If missing, STOP and ask the user to provide the file. Do NOT commit `.env.json` (it is in `.gitignore`).

- [X] T004 [P] Add the `decimal` package to `H:\alnujom-project\pubspec.yaml`. Edit the file's `dependencies:` block (NOT `dev_dependencies:`) and add the line `  decimal: ^3.0.0` in alphabetical order with the existing dependency list. Then run from `H:\alnujom-project`: `flutter pub get`. Confirm the command exits 0 and produces no version-resolution errors. The lockfile (`pubspec.lock`) will update with the resolved `decimal` version. (R-03 partial deviation; R-09.)

- [X] T005 Capture pre-migration baseline to `H:\alnujom-project\specs\009-currencies\baseline-pre-migration.txt` (mirror of Phase 8's `specs/008-locations/baseline-pre-migration.txt`). Concatenate the following sections (use the section headers shown verbatim) into the file: (A) Supabase MCP `list_tables` output for the `public` schema; (B) Supabase MCP `list_migrations` output (full ordered list — the last entry MUST be `20260517120005_phase8_advisor_hardening`); (C) `SELECT count(*) FROM public.currencies` — expected: error `relation "public.currencies" does not exist`; record the error text in the section body; (D) `SELECT key FROM public.permissions WHERE key='currencies.manage'` — expected: one row; record the row verbatim; (E) **Analyzer baseline**: from `H:\alnujom-project`, run `flutter analyze --no-fatal-infos --no-fatal-warnings` and paste the full stdout/stderr verbatim under this section header. This snapshot is the rollback reference if Phase 9 needs to be reverted AND the analyzer-comparison reference for the final polish phase.

**⚠️ Checkpoint A — Setup complete**: Environment confirmed, Phase 8 verified shipped, `.env.json` present, `decimal` package added, baseline snapshot captured. Commit: `git add pubspec.yaml pubspec.lock specs/009-currencies/baseline-pre-migration.txt && git commit -m "chore(009): add decimal dependency + capture pre-migration baseline" && git push`.

---

## Phase 2: Foundational — Backend Migrations (Blocking Prerequisites)

**Purpose**: Apply the 5 Phase 9 migrations + 2 new policy files + 3 new/updated doc files. The 2 new tables, 4 audit triggers, 1 immutability trigger, 6 RLS policies, the `update_exchange_rate` RPC, the FK on `user_preferences.display_currency`, and the full seed inventory all land here. EVERY downstream user story depends on this phase.

**⚠️ CRITICAL**: No user story task may begin until Phase 2 is complete and verified.

### Migration 1 — currencies table

- [X] T006 Author migration 1 file at `H:\alnujom-project\supabase\migrations\20260518120001_create_currencies.sql`. (FR-001, FR-002, FR-004, FR-007, FR-007a, FR-008, FR-009.) Body MUST contain, in exactly this order: (1) leading SQL `-- COMMENT` block citing FR-001/002/004/007/007a/008/009 and noting "anonymous SELECT carve-out — see research.md R-04 and R-16"; (2) `CREATE TABLE IF NOT EXISTS public.currencies (...)` from `data-model.md § Tables § public.currencies` (full body, all 10 columns, all CHECK constraints); (3) `ALTER TABLE public.currencies ENABLE ROW LEVEL SECURITY;`; (4) `set_updated_at` trigger attach (`DROP TRIGGER IF EXISTS set_currencies_updated_at ON public.currencies; CREATE TRIGGER set_currencies_updated_at BEFORE UPDATE ON public.currencies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();`); (5) `enforce_currency_system_immutability` trigger function + trigger from `data-model.md § Triggers § Immutability trigger` (use the full function body verbatim); (6) the 3 audit triggers from `data-model.md § Triggers § Audit triggers` (currencies section — `audit_currencies_insert/update/delete` calling `log_audit('currency.created'/.updated/.deleted', 'currencies', 'code')`); (7) the 4 RLS policies from `data-model.md § RLS policies § public.currencies` (`currencies_select` admitting anon+authenticated USING true; `currencies_insert`/`_update`/`_delete` gated by `current_user_has_permission('currencies.manage')`); (8) seed INSERT of 2 currencies (SYP, USD) from `data-model.md § Seed inventory § public.currencies` using `ON CONFLICT (code) DO NOTHING`. The order matters per R-08 (triggers BEFORE seed). The audit triggers MUST be attached BEFORE step 8 runs so the seed produces 2 audit rows.

- [X] T007 Apply migration 1 via Supabase MCP `apply_migration` with name `20260518120001_create_currencies` and body from T006. Then verify via Supabase MCP `execute_sql`: (a) `SELECT count(*) FROM public.currencies` returns `2`; (b) `SELECT count(*) FROM public.currencies WHERE is_system` returns `2`; (c) `SELECT code, name_ar, name_en, symbol, display_decimals, sort_order FROM public.currencies ORDER BY sort_order` returns SYP row first (sort_order=10, display_decimals=0) then USD (sort_order=20, display_decimals=2); (d) `SELECT count(*) FROM pg_trigger WHERE tgrelid='public.currencies'::regclass AND NOT tgisinternal` returns `5` (3 audit + set_updated_at + enforce_immutability — `pg_trigger` stores one row per `CREATE TRIGGER` statement regardless of how many event verbs that trigger fires on, so `BEFORE UPDATE OR DELETE` counts as exactly 1 row); (e) `SELECT count(*) FROM pg_policies WHERE tablename='currencies'` returns `4`; (f) `SELECT count(*) FROM public.audit_logs WHERE action='currency.created' AND actor_user_id IS NULL` returns `2` (the seed produced audit rows per R-08).

- [X] T008 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\currencies_phase9.sql`. Body MUST be a verbatim copy of the 4 `DROP POLICY IF EXISTS ... CREATE POLICY ...` blocks from migration 1 step (7). Add a leading comment: `-- Mirror of the inline RLS policies in supabase/migrations/20260518120001_create_currencies.sql. R-02 dual-storage invariant — both files MUST be kept in sync at PR review.`

- [X] T009 [P] Author `H:\alnujom-project\supabase\docs\currencies.md`. Body sections (use these exact headings): `# currencies`, `## Purpose`, `## Columns` (table mirroring data-model.md), `## RLS posture` (SELECT anon+authenticated, write gated by currencies.manage), `## Immutability trigger` (refuses DELETE / code-rename on is_system=true), `## Audit triggers` (3 action keys: currency.created/.updated/.deleted), `## Seed inventory` (USD, SYP both is_system=true), `## Notes` (reference R-07, R-08 for the immutability + trigger-before-seed invariants).

### Migration 2 — exchange_rates table

- [X] T010 Author migration 2 file at `H:\alnujom-project\supabase\migrations\20260518120002_create_exchange_rates.sql`. (FR-001, FR-003, FR-005, FR-007, FR-008, FR-009; R-08, R-10.) Body order: (1) leading `-- COMMENT` citing FR-001/003/005/007/008/009 + noting "append-only by RLS — see FR-008 + R-08; anonymous SELECT carve-out — see R-04"; (2) `CREATE TABLE IF NOT EXISTS public.exchange_rates (...)` from `data-model.md § Tables § public.exchange_rates` (full body, all 8 columns, the CHECK `(base_currency <> target_currency)` constraint, the CHECK `(rate > 0)` constraint, the CHECK `(source IS NULL OR length(source) <= 500)` constraint); (3) `ALTER TABLE public.exchange_rates ENABLE ROW LEVEL SECURITY;`; (4) `CREATE INDEX IF NOT EXISTS idx_exchange_rates_base_target_effective ON public.exchange_rates (base_currency, target_currency, effective_at DESC);`; (5) the 1 audit trigger `audit_exchange_rates_insert` calling `log_audit('exchange_rate.updated', 'exchange_rates', 'id')` (INSERT only — NO UPDATE / DELETE triggers because UPDATE/DELETE are blocked by RLS); (6) the 4 RLS policies from `data-model.md § RLS policies § public.exchange_rates` (`exchange_rates_select` anon+authenticated USING true; `exchange_rates_insert` gated by `current_user_has_permission('currencies.manage')`; `exchange_rates_deny_update` USING false; `exchange_rates_deny_delete` USING false); (7) the optional FR-005 starter rate seed from `data-model.md § Seed inventory § public.exchange_rates` using the `DO $$ BEGIN IF NOT EXISTS ... END $$` idempotency wrapper. The audit trigger MUST be attached BEFORE step 7 runs so the 2 seeded rows produce 2 audit rows. Plan-time decision per `data-model.md`: **enact the starter seed** (USD→SYP 15000 + auto-derived inverse).

- [X] T011 Apply migration 2 via Supabase MCP `apply_migration` name `20260518120002_create_exchange_rates` body from T010. Then verify: (a) `SELECT count(*) FROM public.exchange_rates` returns `2`; (b) `SELECT base_currency, target_currency, rate, source FROM public.exchange_rates ORDER BY base_currency` returns two rows — `(SYP, USD, 0.000067, 'auto-derived from seed (USD→SYP)')` and `(USD, SYP, 15000.000000, 'seed')`; (c) `SELECT count(*) FROM pg_trigger WHERE tgrelid='public.exchange_rates'::regclass AND NOT tgisinternal` returns `1` (audit only — NO immutability trigger); (d) `SELECT count(*) FROM pg_policies WHERE tablename='exchange_rates'` returns `4` (select, insert, deny_update, deny_delete); (e) `SELECT count(*) FROM public.audit_logs WHERE action='exchange_rate.updated' AND actor_user_id IS NULL` returns `2`; (f) verify append-only invariant: `UPDATE public.exchange_rates SET rate=99999 WHERE base_currency='USD' AND target_currency='SYP'` — expected: 0 rows affected (RLS deny via `exchange_rates_deny_update USING (false)`).

- [X] T012 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\exchange_rates_phase9.sql`. Body MUST be a verbatim copy of the 4 policy blocks from migration 2 step (6). Add a leading comment: `-- Mirror of the inline RLS policies in supabase/migrations/20260518120002_create_exchange_rates.sql. R-02 dual-storage invariant. The deny_update + deny_delete policies make the append-only invariant explicit even though Postgres RLS defaults to deny when no policy matches.`

- [X] T013 [P] Author `H:\alnujom-project\supabase\docs\exchange_rates.md`. Body sections: `# exchange_rates`, `## Purpose`, `## Columns` (mirroring data-model.md), `## Append-only invariant` (FR-008 — UPDATE and DELETE policies are explicit `USING (false)`; the table is INSERT-only via the `update_exchange_rate` RPC), `## RLS posture` (SELECT anon+authenticated, INSERT gated by currencies.manage), `## Composite index` (base, target, effective_at DESC — for the latest-rate-per-pair lookup), `## Audit trigger` (action key `exchange_rate.updated`), `## Q2 auto-derive contract` (every admin call produces 2 rows: admin + auto-derived inverse with source='auto-derived from <uuid>'), `## Seed inventory` (optional starter USD→SYP=15000 + auto-derived inverse, both set_by=NULL), `## Notes` (reference R-08 trigger-before-seed; R-10 NUMERIC(18,6) precision; R-11 banker's rounding).

### Migration 3 — `update_exchange_rate` RPC

- [X] T014 Author migration 3 file at `H:\alnujom-project\supabase\migrations\20260518120003_create_update_exchange_rate_rpc.sql`. (FR-012, Q2, R-06, R-11.) Body order: (1) leading `-- COMMENT` citing FR-012 + R-06 + R-11 (deviation from implementation plan's Edge Function wording; PL/pgSQL RPC chosen per Phase 7 precedent); (2) `CREATE OR REPLACE FUNCTION public.update_exchange_rate(p_base_currency TEXT, p_target_currency TEXT, p_rate NUMERIC, p_effective_at TIMESTAMPTZ DEFAULT now(), p_source TEXT DEFAULT NULL) RETURNS JSONB LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, auth AS $$ ... $$;` with the full function body verbatim from `data-model.md § update_exchange_rate RPC`. The body MUST: (a) re-check `current_user_has_permission('currencies.manage')` and `RAISE EXCEPTION USING ERRCODE='42501'` on fail; (b) validate `p_base_currency <> p_target_currency` (raise `22023` on fail); (c) validate `p_rate > 0` (raise `22023` on fail); (d) compute `v_derived_rate := round(1.0 / p_rate, 6)`; (e) INSERT admin row into `public.exchange_rates` with `set_by = auth.uid()` and `source = p_source`, capture into `v_admin_row` row-type; (f) INSERT derived row with swapped base/target, `rate = v_derived_rate`, same `set_by`, and `source = format('auto-derived from %s', v_admin_row.id)`; (g) `RETURN jsonb_build_object('admin_row', to_jsonb(v_admin_row), 'derived_row', to_jsonb(v_derived_row));`.

- [X] T015 Apply migration 3 via Supabase MCP `apply_migration` name `20260518120003_create_update_exchange_rate_rpc` body from T014. Then verify: (a) `SELECT proname, prosecdef FROM pg_proc WHERE proname='update_exchange_rate' AND pronamespace='public'::regnamespace` returns 1 row with `prosecdef=t` (SECURITY DEFINER); (b) `SELECT pg_get_function_identity_arguments(oid) FROM pg_proc WHERE proname='update_exchange_rate'` returns `p_base_currency text, p_target_currency text, p_rate numeric, p_effective_at timestamp with time zone, p_source text`; (c) test the function as a `currencies.manage` holder: `SELECT public.update_exchange_rate('USD', 'SYP', 16000)` returns a JSONB with `admin_row` and `derived_row` keys; (d) verify two rows were added: `SELECT count(*) FROM public.exchange_rates WHERE created_at > now() - interval '1 minute'` returns `2`; (e) verify the derived row: `SELECT rate, source FROM public.exchange_rates WHERE base_currency='SYP' AND target_currency='USD' ORDER BY created_at DESC LIMIT 1` — rate should be approximately `0.0000625` (= 1/16000 rounded to 6 decimals), source should start with `'auto-derived from '`; (f) two audit rows: `SELECT count(*) FROM public.audit_logs WHERE action='exchange_rate.updated' AND created_at > now() - interval '1 minute'` returns `2`.

### Migration 4 — `user_preferences.display_currency` FK

- [X] T016 Author migration 4 file at `H:\alnujom-project\supabase\migrations\20260518120004_alter_user_preferences_fk.sql`. (FR-019, SC-022, R-14.) Body: leading `-- COMMENT` citing FR-019 + R-14 (runs after currencies seed so existing 'SYP' default satisfies the FK); then the `DO $$ BEGIN IF NOT EXISTS (...) THEN ALTER TABLE ... ADD CONSTRAINT ...; END IF; END $$;` block verbatim from `data-model.md § Existing tables altered`. The constraint name is `user_preferences_display_currency_fkey`; FK references `public.currencies(code) ON DELETE SET NULL`. **Do NOT** modify any existing `user_preferences` row's value.

- [X] T017 Apply migration 4 via Supabase MCP `apply_migration` name `20260518120004_alter_user_preferences_fk` body from T016. Then verify: (a) `SELECT conname FROM pg_constraint WHERE conname='user_preferences_display_currency_fkey'` returns `1` row; (b) `SELECT confdeltype FROM pg_constraint WHERE conname='user_preferences_display_currency_fkey'` returns `n` (SET NULL); (c) attempt to insert a bogus value: `UPDATE public.user_preferences SET display_currency='ZZZ' WHERE user_id=(SELECT user_id FROM public.user_preferences LIMIT 1)` — expected: `ERROR 23503: insert or update on table "user_preferences" violates foreign key constraint`; (d) verify all existing rows still satisfy the FK: `SELECT count(*) FROM public.user_preferences WHERE display_currency IS NOT NULL AND display_currency NOT IN (SELECT code FROM public.currencies)` returns `0`.

### Migration 5 — advisor hardening

- [X] T018 Author migration 5 file at `H:\alnujom-project\supabase\migrations\20260518120005_phase9_advisor_hardening.sql`. (Constitution III defense-in-depth; R-04, R-16.) Body MUST contain exactly these statements, in this order: (1) leading `-- COMMENT` block: `-- Phase 9: Advisor hardening for currencies + exchange_rates + update_exchange_rate RPC. -- Source: specs/009-currencies/research.md R-04 (anon SELECT carve-out) + R-16 (documented in migration comments). -- Pattern: codify anon GRANTs explicitly + REVOKE write surfaces from anon as defense-in-depth on top of RLS; tighten RPC EXECUTE grants.`; (2) two `GRANT SELECT ON public.<table> TO anon, authenticated;` statements (one each for `currencies`, `exchange_rates`); (3) two `REVOKE INSERT, UPDATE, DELETE ON public.<table> FROM anon;` statements (one each); (4) one `REVOKE EXECUTE ON FUNCTION public.update_exchange_rate(TEXT, TEXT, NUMERIC, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;`; (5) one `GRANT EXECUTE ON FUNCTION public.update_exchange_rate(TEXT, TEXT, NUMERIC, TIMESTAMPTZ, TEXT) TO authenticated;`. **Do NOT** add `ALTER TABLE ... FORCE ROW LEVEL SECURITY` or re-enable RLS (Phase 8 R-17 confirms this pattern).

- [X] T019 Apply migration 5 via Supabase MCP `apply_migration` name `20260518120005_phase9_advisor_hardening` body from T018. Then run Supabase MCP `get_advisors` type=`security` and confirm there are NO new advisor entries beyond what Phase 8 already accepts. Specifically, the new tables and RPC should NOT introduce any of: `function_search_path_mutable` (the RPC sets `search_path` explicitly), `rls_disabled`, `policy_exists_rls_disabled`. If any new lint appears, STOP and investigate — likely indicates a missing `SET search_path` on the RPC or a missing GRANT.

- [X] T020 [P] Update `H:\alnujom-project\supabase\docs\audit_logs.md` to enumerate the 4 new action keys introduced by Phase 9: `currency.created`, `currency.updated`, `currency.deleted`, `exchange_rate.updated`. Use the exact wording pattern Phase 8 used for `governorate.*` / `city.*` / `area.*` keys in the same file. Note the special behavior: `update_exchange_rate` RPC produces TWO `exchange_rate.updated` audit rows per call (admin + auto-derived inverse per Q2), with the second row's `after_state.source` starting with `'auto-derived from '`. 

**⚠️ Checkpoint B — Backend foundation complete**: 5 migrations applied, 2 policy mirror files committed, 3 doc files updated, `get_advisors` clean. Commit: `git add supabase/migrations/20260518* supabase/policies/*phase9*.sql supabase/docs/currencies.md supabase/docs/exchange_rates.md supabase/docs/audit_logs.md && git commit -m "feat(009): backend foundation — currencies + exchange_rates tables, update_exchange_rate RPC, FK, advisor hardening" && git push`.

---

## Phase 2b: Foundational — Flutter Shared Types + Data Layer

**Purpose**: Author every file that downstream user stories will consume — domain entities, repository interface, use cases, DTOs, data source, repository impl, the `Money` value object. The `MoneyFormatter` is **deferred to Phase 3 (US7)** because it owns the formatting story; everything else lives here.

**⚠️ CRITICAL**: No user story task may begin until Phase 2b is complete.

- [X] T021 [P] Create the empty directory structure under `H:\alnujom-project\lib\features\currencies\`: `data\datasources\`, `data\dtos\`, `data\repositories\`, `domain\entities\`, `domain\repositories\`, `domain\usecases\`, `presentation\bloc\`, `presentation\pages\`, `presentation\widgets\`. Use 9 `mkdir -p` calls (or PowerShell equivalent: `New-Item -ItemType Directory -Force -Path <path>` for each).

- [X] T022 [P] Create the empty shared-folder directories: `H:\alnujom-project\lib\shared\domain\value_objects\` (likely already exists from Phase 8); `H:\alnujom-project\lib\shared\presentation\` (create if missing). Verify each exists before proceeding.

### Domain entities and value objects (parallel)

- [X] T023 [P] Create `H:\alnujom-project\lib\shared\domain\value_objects\money.dart` per `contracts\money-value-object.md` § Class shape. The file MUST contain only the imports `package:decimal/decimal.dart` and `package:equatable/equatable.dart`. The class has fields `final Decimal amount;` and `final String currencyCode;`. Constructor `const Money({required this.amount, required this.currencyCode});`. `Equatable.props => [amount, currencyCode];`. NO `rate` field. NO `displayCurrency` field. NO conversion methods. (FR-020, SC-023.)

- [X] T024 [P] Create `H:\alnujom-project\lib\features\currencies\domain\entities\currency.dart` per `data-model.md § Flutter feature folder shapes § currency.dart`. Pure-Dart class, extends `Equatable`. Fields: `code, nameAr, nameEn, symbol, isActive, sortOrder, isSystem, displayDecimals, createdAt, updatedAt` — exact types per data-model.md. Add a `String localizedName(Locale locale)` method implementing the R-18 fallback chain (active locale → other locale → code). Imports: `package:equatable/equatable.dart`, `package:flutter/widgets.dart` (for `Locale`). NO Supabase imports.

- [X] T025 [P] Create `H:\alnujom-project\lib\features\currencies\domain\entities\exchange_rate.dart` per `data-model.md § Flutter feature folder shapes § exchange_rate.dart`. Fields: `id, baseCurrency, targetCurrency, rate (Decimal), effectiveAt, setBy (nullable), source (nullable), createdAt`. Add a computed getter `bool get isDerived => source?.startsWith('auto-derived from ') ?? false;`. Imports: `package:decimal/decimal.dart`, `package:equatable/equatable.dart`. NO Supabase imports.

- [X] T026 [P] Create `H:\alnujom-project\lib\features\currencies\domain\entities\currency_with_latest_rates.dart`. Fields: `final Currency currency;`, `final Map<String, Decimal> latestRates;` (keyed by target currency code). Imports: `package:decimal/decimal.dart`, `package:equatable/equatable.dart`, the new `currency.dart` from T024. `Equatable.props => [currency, latestRates];`.

- [X] T027 [P] Create `H:\alnujom-project\lib\features\currencies\domain\entities\update_exchange_rate_result.dart` per `data-model.md § Flutter feature folder shapes § update_exchange_rate_result.dart`. Two fields: `final ExchangeRate adminRow;`, `final ExchangeRate derivedRow;`. Imports: the new `exchange_rate.dart` from T025, `package:equatable/equatable.dart`.

### Domain repository interface

- [X] T028 Create `H:\alnujom-project\lib\features\currencies\domain\repositories\currencies_repository.dart` per `data-model.md § Flutter feature folder shapes § Repository interface`. Abstract class `CurrenciesRepository` with **12 methods** (the 12th is `countDependentExchangeRates` per A3 fix for the delete-confirmation dialog):

  1. `Future<List<Currency>> listCurrencies({bool activeOnly = false});`
  2. `Future<Currency> loadCurrency(String code);`
  3. `Future<Currency> createCurrency({required String code, required String nameAr, required String nameEn, required String symbol, int sortOrder = 100, int displayDecimals = 2, bool isActive = true});`
  4. `Future<Currency> updateCurrency(Currency updated);`
  5. `Future<void> deleteCurrency(String code);`
  6. `Future<List<ExchangeRate>> listExchangeRateHistory({required String baseCurrency, String? targetCurrencyFilter, int limit = 50, DateTime? cursorBefore});`
  7. `Future<Map<String, Decimal>> loadLatestRatesForBase(String baseCurrency);`
  8. `Future<UpdateExchangeRateResult> setExchangeRate({required String baseCurrency, required String targetCurrency, required Decimal rate, required DateTime effectiveAt, String? source});`
  9. `Future<String?> readUserDisplayCurrency();`
  10. `Future<void> writeUserDisplayCurrency(String code);`
  11. `Future<int> countDependentExchangeRates(String code);` — used by the delete-confirmation dialog (T066). Counts rows where `base_currency = code OR target_currency = code`.

  Imports: only the new domain entities + `package:decimal/decimal.dart`. NO Supabase imports.

### Domain use cases (all parallel — different files)

- [X] T029 [P] Create `H:\alnujom-project\lib\features\currencies\domain\usecases\list_currencies.dart`. Class `ListCurrencies` annotated `@lazySingleton` (lock-in per A15 fix — all 9 Phase 9 use cases use `@lazySingleton`; this matches the Phase 6/7/8 convention. If a quick check via `grep -l "@lazySingleton" lib/features/locations/domain/usecases/*.dart` returns zero matches, fall back to `@injectable` — but the locked default is `@lazySingleton`). Constructor takes a `CurrenciesRepository`. Method `Future<List<Currency>> call({bool activeOnly = false})` delegates to `_repository.listCurrencies(activeOnly: activeOnly)`.

  **Convention applies to all use cases T030-T036 + T035a**: same annotation, same constructor-injected repository field, same `call(...)` method shape. The repository impl (T044) is `@LazySingleton(as: CurrenciesRepository)`. The data source (T043) is `@injectable`. BLoCs (T060, T061, T062, T079) are `@injectable` (not lazySingleton — they hold per-screen state).

- [X] T030 [P] Create `H:\alnujom-project\lib\features\currencies\domain\usecases\load_currency_detail.dart`. Class `LoadCurrencyDetail` with `call(String code)` returning `Future<Currency>`.

- [X] T031 [P] Create `H:\alnujom-project\lib\features\currencies\domain\usecases\create_currency.dart`. Class `CreateCurrency` with `call({required String code, required String nameAr, required String nameEn, required String symbol, int sortOrder = 100, int displayDecimals = 2, bool isActive = true})` returning `Future<Currency>`.

- [X] T032 [P] Create `H:\alnujom-project\lib\features\currencies\domain\usecases\update_currency.dart`. Class `UpdateCurrency` with `call(Currency updated)` returning `Future<Currency>`.

- [X] T033 [P] Create `H:\alnujom-project\lib\features\currencies\domain\usecases\delete_currency.dart`. Class `DeleteCurrency` with `call(String code)` returning `Future<void>`.

- [X] T034 [P] Create `H:\alnujom-project\lib\features\currencies\domain\usecases\list_exchange_rate_history.dart`. Class `ListExchangeRateHistory` with `call({required String baseCurrency, String? targetCurrencyFilter, int limit = 50, DateTime? cursorBefore})` returning `Future<List<ExchangeRate>>`.

- [X] T035 [P] Create `H:\alnujom-project\lib\features\currencies\domain\usecases\set_exchange_rate.dart`. Class `SetExchangeRate` with `call({required String baseCurrency, required String targetCurrency, required Decimal rate, required DateTime effectiveAt, String? source})` returning `Future<UpdateExchangeRateResult>`.

- [X] T035a [P] Create `H:\alnujom-project\lib\features\currencies\domain\usecases\count_dependent_exchange_rates.dart`. Class `CountDependentExchangeRates` annotated `@lazySingleton` (or matching project convention from T029). Method `Future<int> call(String code)` delegates to `_repository.countDependentExchangeRates(code)`. Consumed by the `delete_currency_confirmation_dialog.dart` caller in T068 (the caller pre-fetches the count before showing the dialog).

- [X] T036 [P] Create `H:\alnujom-project\lib\features\currencies\domain\usecases\select_listing_price_row.dart` per `contracts\listing-price-row-selection.md`. Copy the file body **verbatim**:

  ```dart
  /// FR-019a row-selection rule. Q1 / Q4-aware.
  /// See contracts/listing-price-row-selection.md.
  ListingPriceRowLike? selectListingPriceRow(
    Iterable<ListingPriceRowLike> rows, {
    required String? viewerPreferredCurrencyCode,
  }) {
    if (viewerPreferredCurrencyCode != null) {
      for (final row in rows) {
        if (row.currencyCode == viewerPreferredCurrencyCode) {
          return row;
        }
      }
    }
    for (final row in rows) {
      if (row.isPrimary) {
        return row;
      }
    }
    return null;
  }

  abstract class ListingPriceRowLike {
    String get currencyCode;
    bool get isPrimary;
  }
  ```

  Pure Dart, no async, no I/O. No generics (the contract examples use plain `ListingPriceRowLike`). No imports beyond `package:meta/meta.dart` if `@immutable` is used (optional). NO Supabase imports.

### DTOs (all parallel — different files)

- [X] T037 [P] Create `H:\alnujom-project\lib\features\currencies\data\dtos\currency_dto.dart`. Mirrors `public.currencies` columns. Has `Currency toDomain()` mapper and `factory CurrencyDto.fromJson(Map<String, dynamic> json)` constructor. Use `Decimal.parse()` to convert numeric strings from Postgres if needed (but `currencies` has no Decimal column; `display_decimals` is `int`).

- [X] T038 [P] Create `H:\alnujom-project\lib\features\currencies\data\dtos\exchange_rate_dto.dart`. Mirrors `public.exchange_rates` columns. The `rate` field maps to `Decimal` via `Decimal.parse(json['rate'] is String ? json['rate'] as String : json['rate'].toString())` (Postgrest may return `NUMERIC` as String, int, or double depending on value magnitude — always-coerce-to-String-first is safe). Has `ExchangeRate toDomain()` mapper.

  **Additional optional field for history rendering (per T080 / A2 fix)**: when the DTO is constructed from the history-query response (which includes a joined `profiles(display_name, username)` sub-object — see T043 `listExchangeRateHistory` for the exact PostgREST select string), expose a `String? setByDisplayName` field. Resolution rule: `profiles?.display_name ?? profiles?.username` (first non-null), else `null`. The base `ExchangeRate` domain entity does NOT gain a new field; instead, `exchange_rate_row.dart` (T080) consumes `dto.setByDisplayName` directly OR you may add a parallel `ExchangeRateHistoryView` projection class — simplest path: add `setByDisplayName` to `ExchangeRate` as a nullable transient field set only on history reads.

- [X] T039 [P] Create `H:\alnujom-project\lib\features\currencies\data\dtos\currency_with_latest_rates_dto.dart`. Carries the currency row + a `Map<String, Decimal>` of latest outbound rates. Has `CurrencyWithLatestRates toDomain()`.

- [X] T040 [P] Create `H:\alnujom-project\lib\features\currencies\data\dtos\update_exchange_rate_request_dto.dart`. Carries the inputs to the RPC: `baseCurrency`, `targetCurrency`, `rate (Decimal)`, `effectiveAt (DateTime)`, `sourceText (String?)`.

  `Map<String, dynamic> toRpcParams()` MUST return **exactly** the following shape (keys are `p_*` prefixed because Postgres function signature uses `p_*` parameter names — non-prefixed keys will silently bind to function defaults and the call will misbehave):

  ```dart
  Map<String, dynamic> toRpcParams() => {
        'p_base_currency': baseCurrency,
        'p_target_currency': targetCurrency,
        'p_rate': rate.toString(), // Decimal → String for NUMERIC binding
        'p_effective_at': effectiveAt.toUtc().toIso8601String(),
        if (sourceText != null) 'p_source': sourceText,
      };
  ```

  Conditional `if (sourceText != null)` lets Postgres use the DEFAULT NULL when source is omitted.

- [X] T041 [P] Create `H:\alnujom-project\lib\features\currencies\data\dtos\update_exchange_rate_response_dto.dart`. Matches the RPC's `{admin_row, derived_row}` JSONB shape. Has `UpdateExchangeRateResult toDomain()` that constructs two `ExchangeRate` instances from the nested objects.

- [X] T042 [P] Create `H:\alnujom-project\lib\features\currencies\data\dtos\currency_mutation_request_dto.dart`. Carries the inputs to a currencies INSERT/UPDATE: `code`, `nameAr`, `nameEn`, `symbol`, `sortOrder`, `displayDecimals`, `isActive`. Has `Map<String, dynamic> toRow()` for the Postgrest INSERT/UPDATE call.

### Data layer (sequential — same files imported by each other)

- [X] T043 Create `H:\alnujom-project\lib\features\currencies\data\datasources\supabase_currencies_datasource.dart`. Annotated `@injectable`. Constructor takes a `SupabaseClient` (resolved via DI). Methods correspond 1:1 to the repository methods T028 lists; each performs the Postgrest query or RPC call. DO NOT cache anything (R-20). Map all SQLSTATE errors to the localized exception types defined in T044 (`CurrenciesFailure`). Locked method bodies follow — copy the PostgREST / SQL snippets verbatim:

  **listCurrencies({activeOnly})**:
  ```dart
  var query = _client.from('currencies').select();
  if (activeOnly) query = query.eq('is_active', true);
  final rows = await query.order('sort_order', ascending: true).order('code', ascending: true);
  ```

  **loadCurrency(code)**: `await _client.from('currencies').select().eq('code', code).single();`

  **createCurrency / updateCurrency / deleteCurrency**: standard PostgREST `.insert(toRow()).select().single()` / `.update(toRow()).eq('code', code).select().single()` / `.delete().eq('code', code)`.

  **setExchangeRate(requestDto)**: `await _client.rpc('update_exchange_rate', params: requestDto.toRpcParams()).select().single();` then `UpdateExchangeRateResponseDto.fromJson(result as Map<String, dynamic>).toDomain()`.

  **readUserDisplayCurrency()**:
  ```dart
  final userId = _client.auth.currentUser?.id;
  if (userId == null) return null;
  final row = await _client
      .from('user_preferences')
      .select('display_currency')
      .eq('user_id', userId)
      .maybeSingle();
  return row?['display_currency'] as String?;
  ```

  **writeUserDisplayCurrency(code)** — explicit `.eq('user_id', ...)` even though RLS enforces self-only writes:
  ```dart
  final userId = _client.auth.currentUser!.id;
  await _client
      .from('user_preferences')
      .update({'display_currency': code})
      .eq('user_id', userId);
  ```

  **listExchangeRateHistory** — PostgREST select string includes the joined profile to resolve `set_by` display name in a single round-trip (A2 fix):
  ```dart
  var query = _client
      .from('exchange_rates')
      .select('*, profiles:set_by(display_name, username)') // PostgREST FK-join syntax
      .eq('base_currency', baseCurrency);
  if (targetCurrencyFilter != null) {
    query = query.eq('target_currency', targetCurrencyFilter);
  }
  if (cursorBefore != null) {
    query = query.lt('created_at', cursorBefore.toUtc().toIso8601String());
  }
  final rows = await query.order('effective_at', ascending: false).limit(limit);
  // Each row carries: every exchange_rates column + a nested
  // 'profiles' object { display_name, username } or null (if set_by IS NULL).
  // ExchangeRateDto.fromJson reads json['profiles']?['display_name'] ?? json['profiles']?['username'].
  ```

  **loadLatestRatesForBase(baseCurrency)** — locked SQL (A1 fix) uses Postgres `DISTINCT ON` over the composite index `idx_exchange_rates_base_target_effective`:
  ```dart
  // Postgrest does NOT expose DISTINCT ON directly. Approach: register a small
  // RPC `latest_rates_for_base(p_base_currency TEXT) RETURNS TABLE(...)` in a
  // helper migration, OR call execute_sql via a server-side function. Locked
  // choice: add the RPC. Author it in T043a (below); call via
  // _client.rpc('latest_rates_for_base', params: {'p_base_currency': baseCurrency}).
  final rows = await _client.rpc(
    'latest_rates_for_base',
    params: {'p_base_currency': baseCurrency},
  );
  final list = rows as List<dynamic>;
  return {
    for (final r in list)
      (r as Map<String, dynamic>)['target_currency'] as String:
          Decimal.parse(r['rate'].toString()),
  };
  ```

  **countDependentExchangeRates(code)** — used by the delete-confirmation dialog (A3 fix):
  ```dart
  final result = await _client
      .from('exchange_rates')
      .select('id', const FetchOptions(count: CountOption.exact, head: true))
      .or('base_currency.eq.$code,target_currency.eq.$code');
  return result.count ?? 0;
  // If the supabase_flutter version differs, use the equivalent count-only
  // pattern documented at https://supabase.com/docs/reference/dart/select.
  ```

- [X] T043a Author the supporting Postgres RPC for `loadLatestRatesForBase`. Add a new migration file `H:\alnujom-project\supabase\migrations\20260518120006_create_latest_rates_for_base_rpc.sql`. Body:

  ```sql
  -- Phase 9 helper: latest rate per (base, target) pair for a given base currency.
  -- Read-only; reuses the idx_exchange_rates_base_target_effective composite index
  -- via DISTINCT ON. Anonymous + authenticated may call (read-only, same posture
  -- as the SELECT policy on public.exchange_rates).

  CREATE OR REPLACE FUNCTION public.latest_rates_for_base(p_base_currency TEXT)
  RETURNS TABLE (target_currency TEXT, rate NUMERIC, effective_at TIMESTAMPTZ)
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path = public
  AS $$
    SELECT DISTINCT ON (er.target_currency)
      er.target_currency,
      er.rate,
      er.effective_at
    FROM public.exchange_rates er
    WHERE er.base_currency = p_base_currency
      AND er.effective_at <= now()
    ORDER BY er.target_currency, er.effective_at DESC, er.created_at DESC;
  $$;

  REVOKE EXECUTE ON FUNCTION public.latest_rates_for_base(TEXT) FROM PUBLIC;
  GRANT EXECUTE ON FUNCTION public.latest_rates_for_base(TEXT) TO anon, authenticated;
  ```

  Apply via Supabase MCP `apply_migration` with name `20260518120006_create_latest_rates_for_base_rpc`. Verify: `SELECT * FROM public.latest_rates_for_base('USD')` returns one row per distinct `target_currency`, ordered DESC by `effective_at`. Verify anonymous role can EXECUTE: `SET ROLE anon; SELECT * FROM public.latest_rates_for_base('USD'); RESET ROLE;` succeeds with the same rows.

- [X] T044 Create `H:\alnujom-project\lib\features\currencies\data\repositories\currencies_repository_impl.dart`. Annotated `@LazySingleton(as: CurrenciesRepository)`. Constructor takes the datasource from T043. Each method delegates to the datasource with DTO ↔ domain mapping. **REQUIRED** (not optional per A16 fix): define a sealed class `CurrenciesFailure` at the bottom of the same file with these variants:

  ```dart
  sealed class CurrenciesFailure implements Exception {
    final String technicalMessage;
    const CurrenciesFailure(this.technicalMessage);
  }
  class CurrenciesPermissionDenied extends CurrenciesFailure {
    const CurrenciesPermissionDenied(super.technicalMessage);
  }
  class CurrenciesValidationFailed extends CurrenciesFailure {
    final String reason; // 'rate_must_be_positive' | 'base_equals_target' | 'display_decimals_range' | etc.
    const CurrenciesValidationFailed(this.reason, super.technicalMessage);
  }
  class CurrenciesSystemRowImmutable extends CurrenciesFailure {
    const CurrenciesSystemRowImmutable(super.technicalMessage);
  }
  class CurrenciesHasReferences extends CurrenciesFailure {
    const CurrenciesHasReferences(super.technicalMessage);
  }
  class CurrenciesDuplicateCode extends CurrenciesFailure {
    const CurrenciesDuplicateCode(super.technicalMessage);
  }
  class CurrenciesUnknown extends CurrenciesFailure {
    const CurrenciesUnknown(super.technicalMessage);
  }
  ```

  **SQLSTATE mapping** (the repository impl wraps each datasource call in a try/catch on `PostgrestException` and re-throws the appropriate `CurrenciesFailure`):
  - `42501` → `CurrenciesPermissionDenied`
  - `22023` → `CurrenciesValidationFailed(reason: parse from message)`
  - Custom error matching "system" or "immutable" in the message → `CurrenciesSystemRowImmutable`
  - `23503` (FK violation on delete) → `CurrenciesHasReferences`
  - `23505` (unique violation on currencies.code) → `CurrenciesDuplicateCode`
  - Anything else → `CurrenciesUnknown(originalMessage)`

  BLoCs and pages map each `CurrenciesFailure` variant to a localized error string from the ARB inventory (FR-024).

- [X] T045 Run DI codegen: from `H:\alnujom-project`, run `dart run build_runner build --delete-conflicting-outputs`. Confirm `injection.config.dart` now contains entries for `CurrenciesRepositoryImpl`, `SupabaseCurrenciesDatasource`, and all 8 use cases (T029-T036). If codegen fails, fix annotations and re-run.

- [X] T046 [P] Add a permission-key constant check. Open `H:\alnujom-project\lib\core\security\permission_keys.dart`. Confirm a constant like `currenciesManage = 'currencies.manage'` already exists from Phase 6. If named differently (e.g., `currenciesManageKey`), use the existing name throughout the new Phase 9 code. Record the exact name as a note in the file or at the top of `lib/features/currencies/domain/repositories/currencies_repository.dart` so downstream tasks reference the same string.

**⚠️ Checkpoint C — Flutter foundation complete**: All domain entities, repository interface + impl, data source, DTOs, use cases, and DI codegen in place. Run `flutter analyze --no-fatal-infos --no-fatal-warnings` and confirm zero NEW warnings vs the baseline captured in T005 § E. Commit: `git add lib/shared/domain/value_objects/money.dart lib/features/currencies/ && git commit -m "feat(009): Flutter foundation — Money value object + domain entities + data layer + use cases + DI codegen" && git push`.

---

## Phase 3: User Story 7 — MoneyFormatter (Priority: P1)

**Why first among user stories**: US3 (admin sets rate) and US6 (history page) both render formatted rate values via `MoneyFormatter` — particularly the derived-rate preview in `SetExchangeRatePage` (FR-016). Implementing the formatter before US3/US6 unblocks them. US1 (public read) and US2 (admin tile) do not depend on the formatter.

**Goal**: Ship `MoneyFormatter.format(money, locale, currency)` + a debug-only `MoneyFormatterShowcasePage` rendering the 10 plan-time-locked golden cases (per `quickstart.md` Step 8).

**Independent Test**: Open `/debug/money-formatter` on the device. Confirm each of the 10 golden cases renders the locked expected output in both `ar` and `en` locales. Toggle the device locale; confirm each row re-renders correctly.

- [X] T047 [P] [US7] Create `H:\alnujom-project\lib\shared\presentation\money_formatter.dart` per `contracts\money-formatter.md`. Public API: `class MoneyFormatter { static String format(Money money, {required Locale locale, required Currency currency}); }`. Imports: `package:flutter/widgets.dart` (for `Locale`), `package:intl/intl.dart` as `intl`, `package:decimal/decimal.dart`, `../domain/value_objects/money.dart`, `../../features/currencies/domain/entities/currency.dart`. The function MUST NOT accept a `rate` parameter (SC-023). NO global state (R-17).

  **Locked rounding implementation** (decimal `^3.0.0` — A5 fix). `decimal: ^3.0.0` exposes `Decimal.round({int scale = 0})` which truncates rather than performing half-even. To achieve banker's rounding (R-11 half-to-even), use the explicit helper below:

  ```dart
  /// Round [value] to [scale] decimal places using banker's rounding
  /// (half-to-even). Independent of decimal's built-in round() behavior.
  Decimal _roundHalfEven(Decimal value, int scale) {
    if (scale < 0) throw ArgumentError.value(scale, 'scale', 'must be >= 0');
    final factor = Decimal.fromInt(10).pow(scale).toDecimal();
    final scaled = value * factor; // shift decimal point right by `scale`
    final truncated = scaled.truncate(); // integer part
    final fractional = scaled - truncated; // [0, 1) absolute fractional
    final absFrac = fractional.abs();
    final half = Decimal.parse('0.5');
    Decimal rounded;
    if (absFrac < half) {
      rounded = truncated;
    } else if (absFrac > half) {
      // Round away from zero
      rounded = value.signum >= 0 ? truncated + Decimal.one : truncated - Decimal.one;
    } else {
      // Exactly 0.5 fractional → round to even
      final isEven = (truncated.toBigInt() % BigInt.two) == BigInt.zero;
      if (isEven) {
        rounded = truncated;
      } else {
        rounded = value.signum >= 0 ? truncated + Decimal.one : truncated - Decimal.one;
      }
    }
    return (rounded / factor).toDecimal(scaleOnInfinitePrecision: scale);
  }
  ```

  Call from `format`: `final rounded = _roundHalfEven(money.amount, currency.displayDecimals);` then format `rounded` for display.

  **Implementation outline**:

  (a) Compute `rounded` via the helper above.

  (b) Resolve the symbol via `_resolveSymbol(currency, locale)`:
  - For `locale.languageCode == 'ar' && currency.code == 'SYP'` return `'ل.س'` (R-12 custom override; per R-12 the override is for ar locale only — the `currencies.symbol` column value is the source of truth in other locales).
  - For `locale.languageCode == 'en' && currency.code == 'SYP'` return `'SYP'` (code, not symbol, in English).
  - Else return `currency.symbol`.

  (c) Construct an `intl.NumberFormat.decimalPattern(locale.toLanguageTag())` and set `minimumFractionDigits = maximumFractionDigits = currency.displayDecimals`. Format `rounded.toDouble()` ONLY if `displayDecimals <= 6` AND the magnitude is small enough to avoid double-precision loss — for large amounts (>= 10^15), format the rounded `Decimal` directly by splitting on the decimal point and joining digit groups manually. For Phase 9's USD + SYP (and realistic amounts <= 10^12), `rounded.toDouble()` is safe.

  (d) Position the symbol per locale:
  - `ar` locale → `'{amount} {symbol}'` (amount + NBSP + symbol, RTL bidi resolver handles visual order).
  - `en` locale + symbol is single Latin char (e.g., `$`) → `'{symbol}{amount}'`.
  - `en` locale + symbol is multi-char or non-Latin → `'{amount} {symbol}'`.

  Return the formatted string.

- [X] T048 [US7] Create `H:\alnujom-project\lib\features\currencies\presentation\pages\money_formatter_showcase_page.dart` per `research.md § R-21`. Page class `MoneyFormatterShowcasePage extends StatelessWidget`. The body renders a `ListView` of 10 cards, each card showing: (a) the input `{amount, currency}` as text on top; (b) **two side-by-side columns** rendering the same `MoneyFormatter.format(...)` call output twice — left column labeled "Call 1", right column labeled "Call 2" — both for the Arabic locale; below them, the same two-column layout for the English locale. This enables the SC-013 byte-identical visual diff at the bottom of T050. The 10 inputs are exactly the 10 cases in `quickstart.md` Step 8: (1) `{750000000, SYP}`, (2) `{50000, USD}`, (3) `{1234567.89, USD}`, (4) `{0, SYP}`, (5) `{0, USD}`, (6) `{1, SYP}`, (7) `{49999.997, USD}`, (8) `{49999.995, USD}`, (9) `{-50, USD}`, (10) `{15000.5, SYP}`. Each card also displays the locked expected output text from `quickstart.md` Step 8 beneath the formatter's actual output for visual comparison. The page reads the `Currency` row for SYP and USD from the `ListCurrencies` use case (mounted via DI) — do NOT hardcode the `Currency` constructor.

- [X] T049 [US7] Register the debug route `/debug/money-formatter` in `H:\alnujom-project\lib\core\routing\app_router.dart` (the same file edited in T057). At the top of the file, add `import 'package:flutter/foundation.dart' show kDebugMode;`. Wrap the route registration in `if (kDebugMode) ...[ GoRoute(path: '/debug/money-formatter', builder: (_, __) => const MoneyFormatterShowcasePage()), ]` so production builds skip it (the spread operator on a const list inside the routes list is the idiomatic way). The route renders `MoneyFormatterShowcasePage`. No route guard needed (debug-only; the route is not registered in production).

- [X] T050 [US7] **Manual verification** — open `/debug/money-formatter` on the reference Infinix Note 8 with locale set to Arabic. Walk through each of the 10 rows; confirm the rendered output exactly matches the locked expected output column. Switch device locale to English; confirm each row re-renders correctly. If any row mismatches, fix the formatter (do NOT alter the golden expected values) and re-verify. Capture screenshots or note the verification in `H:\alnujom-project\specs\009-currencies\quickstart.md` step 8 as "verified 2026-XX-XX".

  **SC-013 byte-identical determinism sub-step**: the showcase page renders each input twice in a row (left column = "first call", right column = "second call" — both produced by the same `MoneyFormatter.format(...)` invocation). Visually confirm for all 10 cases that the two columns are byte-identical (same digits, same spacing, same symbol position). If any case shows a difference (which would indicate hidden global state per R-17), STOP and investigate.

**⚠️ Checkpoint D — US7 complete**: `MoneyFormatter` + showcase page exist; 10 golden cases verified manually in both locales. Commit: `git add lib/shared/presentation/money_formatter.dart lib/features/currencies/presentation/pages/money_formatter_showcase_page.dart lib/app.dart && git commit -m "feat(009): US7 — MoneyFormatter utility + debug-only showcase page (10 golden cases manually verified)" && git push`.

---

## Phase 4: User Story 1 — Public Read of Currencies Catalog (Priority: P1)

**Goal**: Verify the seeded `USD` and `SYP` currency rows + any seeded exchange rate are readable by anonymous + authenticated clients via the RLS policies authored in T006/T010.

**Independent Test**: From an anonymous Supabase client, `SELECT * FROM public.currencies` returns 2 rows. From the Flutter device, the catalog reads succeed without sign-in (smoke-tested implicitly via T048's showcase page which calls `ListCurrencies`).

US1 is **verification-only** — every behavioral output is already produced by Phase 2 + Phase 2b. The tasks below are SQL probes confirming the behavior matches the spec.

- [X] T051 [US1] Run `quickstart.md` Step 2 verbatim. Capture each query's actual output to a session log. Expected: 2 currency rows from anon SELECT; 2 (or 0) exchange_rates rows from anon SELECT; INSERT attempt as anon refused with RLS violation.

- [X] T052 [US1] Verify the R-18 locale-fallback rendering of currency names. Open the showcase page from T048 with locale `ar` — confirm USD displays as "دولار أمريكي" and SYP as "ليرة سورية". Toggle to `en` — confirm USD displays as "US Dollar" and SYP as "Syrian Pound". (FR-024 / R-18.)

- [X] T053 [US1] Verify a regular `user`-role session (Phase 5 default role) sees the same 2 currency rows as the anonymous client. Sign in as a non-admin test account; mount the showcase page; confirm USD + SYP both appear.

**⚠️ Checkpoint E — US1 verified**: Public reads work for anonymous + authenticated clients. No code changes. No commit needed.

---

## Phase 5: User Story 2 — Admin Tile + Route Guard (Priority: P1)

**Goal**: A `currencies.manage` holder sees a "Currencies" tile on the admin home page; non-holders do not. The four currencies admin routes are guarded by the same permission predicate.

**Independent Test**: Sign in as Phase 5 admin — confirm the Currencies tile renders. Sign in as moderator — confirm the tile is hidden and `/admin/currencies` deep-link redirects to unauthorized.

- [X] T054 [P] [US2] Add the ARB key `adminHomeCurrenciesTile` to `H:\alnujom-project\lib\l10n\app_ar.arb` with value `'العملات'` and to `H:\alnujom-project\lib\l10n\app_en.arb` with value `'Currencies'`. Add `@adminHomeCurrenciesTile` description metadata in both files: `"Currencies admin-home tile label"`. Run `flutter gen-l10n` if the project uses generated localizations (otherwise the Phase 3 ARB pipeline handles it on next analyzer run).

- [X] T055 [P] [US2] Add 4 ARB keys for the 4 new page titles to both `app_ar.arb` and `app_en.arb`: `currenciesPageTitle` (`العملات` / `Currencies`), `setExchangeRatePageTitle` (`تعيين سعر صرف` / `Set exchange rate`), `exchangeRateHistoryPageTitle` (`سجل أسعار الصرف` / `Exchange rate history`), `currencyFormPageTitle` (`عملة` / `Currency`). Each with an `@<key>` description.

- [X] T056 [US2] Update `H:\alnujom-project\lib\features\admin\presentation\pages\admin_home_page.dart` (confirmed-existing absolute path) to add the Currencies tile. Open the file and search for the existing Locations tile (the Phase 8 pattern — search for `adminHomeLocationsTile` ARB key reference). Insert a new tile widget IMMEDIATELY AFTER the Locations tile in the same column/grid container, gated by `PermissionChecker.has(PermissionKeys.<currenciesManage-constant-name-from-T046>)`. Tile properties: localized title from `AppLocalizations.of(context).adminHomeCurrenciesTile`, icon `Icons.currency_exchange` (Material Icons standard for FX-related screens — match the project's icon convention if it differs, but the symbol is universally recognized), navigation on tap to `context.go('/admin/currencies')`. The tile is HIDDEN (not dimmed) for non-holders — wrap with `if (PermissionChecker.has(...)) AdminTile(...)` rather than passing `enabled: false`.

- [X] T057 [US2] Update the router config at `H:\alnujom-project\lib\core\routing\app_router.dart` (confirmed-existing path). Add four route entries: `/admin/currencies` → `CurrenciesListPage`, `/admin/currencies/set-rate` → `SetExchangeRatePage`, `/admin/currencies/:code/history` → `ExchangeRateHistoryPage`, `/admin/currencies/form` → `CurrencyFormPage` (with query params `mode` and optional `code` for edit). The pages themselves are stubbed in this task — create thin placeholder widgets in `H:\alnujom-project\lib\features\currencies\presentation\pages\` that just render `Scaffold(appBar: AppBar(title: Text(<localizedTitle>)))`; full implementations land in US3/US6.

- [X] T058 [US2] Update `H:\alnujom-project\lib\core\routing\auth_redirect.dart` (confirmed-existing path). Open the file; locate the existing `/admin/locations/*` guard block (added by Phase 8). Add an immediately parallel block for routes matching the regex `^/admin/currencies(/.*)?$`. The guard reads `PermissionChecker.has(PermissionKeys.<currenciesManage-from-T046>)`; if false, returns the same admin-route-unauthorized destination Phase 8's guard returns (copy that destination value verbatim from the Phase 8 block to preserve consistency).

- [X] T059 [US2] **Manual verification on the reference Infinix Note 8**: (a) sign in as Phase 5 admin — confirm Currencies tile renders; tap it — confirm `CurrenciesListPage` (placeholder) opens; (b) sign out, sign in as moderator — confirm Currencies tile is absent; (c) hand-type `/admin/currencies` as a deep-link — confirm redirect to unauthorized destination; (d) hand-type `/admin/currencies/set-rate` and `/admin/currencies/USD/history` and `/admin/currencies/form` — confirm each is refused; (e) sign back in as admin — confirm `/admin/currencies/USD/history` deep-link navigates correctly (placeholder page).

  **Verification 2026-05-18**: Sub-step (a) verified on Android emulator — Currencies tile renders for admin, tap opens `CurrenciesListPage`, deep-link `/admin/currencies/USD/history` resolves. Sub-step (b) verified via own-role revoke approach: temporarily DELETEd the `(super_admin, currencies.manage)` row from `role_permissions`, user backgrounded+foregrounded the app, **Currencies tile disappeared** from `admin_home_page.dart` (line 44 `PermissionKeys.currenciesManage` gate), then restored the row and the tile reappeared on next foreground — proving the FR-015 three-point cache refresh in both directions. Sub-steps (c/d) deep-link refusals: code-review verified — `requireCurrenciesManageRedirect` (`auth_redirect.dart:91-99`) wired to all four routes (`app_router.dart:226,232,240,248`). Sub-step (f) RLS deny verified — see T040/T044 + quickstart Step 10 evidence.

  **(f) SC-011 RLS deny verification (third-layer gate)**: while signed in as the moderator account on the desktop browser (Supabase Studio's SQL editor with the moderator's JWT), run three direct SQL probes — these BYPASS the UI gate (a) and the route guard (b) entirely and exercise the third-layer RLS deny:
  - `INSERT INTO public.currencies (code, name_ar, name_en, symbol, sort_order) VALUES ('EUR', 'يورو', 'Euro', '€', 30);` → expected: `ERROR: new row violates row-level security policy for table "currencies"` (or rowsAffected=0 depending on the Postgrest path).
  - `SELECT public.update_exchange_rate('USD', 'SYP', 16000);` → expected: `ERROR 42501: insufficient_privilege` raised by the RPC's first permission re-check.
  - `INSERT INTO public.exchange_rates (base_currency, target_currency, rate) VALUES ('USD', 'SYP', 99999);` → expected: RLS violation.

  All three must fail. If any succeeds, an RLS policy is misconfigured — STOP and re-verify migrations 1 and 2 before continuing.

**⚠️ Checkpoint F — US2 complete**: Admin tile gated, four routes registered + guarded. Commit: `git add lib/features/admin/presentation/pages/admin_home_page.dart lib/app.dart lib/core/routing/auth_redirect.dart lib/l10n/*.arb lib/features/currencies/presentation/pages/ && git commit -m "feat(009): US2 — Currencies admin tile + 4 routes + three-layer permission gate" && git push`.

---

## Phase 6: User Story 3 — Admin Sets a New Rate via RPC (Priority: P1)

**Goal**: A `currencies.manage` holder opens `CurrenciesListPage`, sees existing currencies + their latest rates, navigates to `SetExchangeRatePage`, submits a new rate, and observes the atomic two-row INSERT (admin + auto-derived inverse) per Q2.

**Independent Test**: Per `quickstart.md` Step 5 — set USD → SYP = 16000 from the device; verify 2 rows + 2 audit rows landed in under 60 seconds.

### BLoCs and helper widgets (parallel — different files)

- [X] T060 [P] [US3] Create `H:\alnujom-project\lib\features\currencies\presentation\bloc\currencies_list_bloc.dart` per `data-model.md § BLoC shapes`. States: `Initial / Loading / Loaded(List<CurrencyWithLatestRates>) / Error(message)`. Events: `LoadCurrencies`, `RefreshCurrencies`, `CurrencyMutated(code)` (re-fetches the row). Constructor injects `ListCurrencies` use case + a `loadLatestRatesForBase` (or expose via a dedicated use case if needed) — match the Phase 8 BLoC pattern.

- [X] T061 [P] [US3] Create `H:\alnujom-project\lib\features\currencies\presentation\bloc\currency_form_bloc.dart`. Annotated `@injectable`. Define an enum at the top of the file: `enum FormMode { create, edit }`. States: `Idle(FormMode mode, Map<String, dynamic> fieldValues) / Validating(FormMode mode, Map<String, dynamic> fieldValues) / Saving(FormMode mode, Map<String, dynamic> fieldValues) / SaveSuccess(Currency saved) / SaveFailure(String reason, FormMode mode, Map<String, dynamic> fieldValues)`. Events: `Initialize(FormMode mode, {String? code})` (dispatched by the page on mount — when `mode==edit`, the BLoC also calls `LoadCurrencyDetail(code)` and pre-fills `fieldValues` from the loaded `Currency`), `EditFieldChanged(name, value)` (updates `fieldValues[name]` in the current state), `SubmitPressed`. Constructor injects `CreateCurrency` + `UpdateCurrency` + `LoadCurrencyDetail` use cases.

  **Branching on SubmitPressed** (A12 fix): the handler reads `state.mode`:
  - `FormMode.create` → call `CreateCurrency(...)` with all field values from `state.fieldValues`. On success, emit `SaveSuccess(newCurrency)`.
  - `FormMode.edit` → call `UpdateCurrency(Currency.fromForm(state.fieldValues))`. On success, emit `SaveSuccess(updated)`.
  - On exception, emit `SaveFailure(reasonFromSqlState, mode, fieldValues)` so the form re-renders with the user's edits preserved.

  No transient mode state — `mode` lives in the state object from `Initialize` onward.

- [X] T062 [P] [US3] Create `H:\alnujom-project\lib\features\currencies\presentation\bloc\set_exchange_rate_bloc.dart` per `data-model.md § BLoC shapes`. Annotated `@injectable`.

  **State carries the full form values throughout** (so `UnusualTimingConfirmed` can replay the submit without re-reading the page):

  ```dart
  class SetExchangeRateState extends Equatable {
    final String? baseCurrency;
    final String? targetCurrency;
    final Decimal? rate;
    final DateTime effectiveAt;
    final String? sourceText;
    final Decimal? derivedRatePreview; // computed from rate
    final SetRateStatus status; // enum: idle, saving, saveSuccess, saveFailure, unusualTimingPending
    final String? failureReason;
    final UpdateExchangeRateResult? saveResult;
    // copyWith(...) + props
  }
  enum SetRateStatus { idle, saving, saveSuccess, saveFailure, unusualTimingPending }
  ```

  **Events**: `BaseChanged(code)`, `TargetChanged(code)`, `RateChanged(Decimal)`, `EffectiveAtChanged(DateTime)`, `SourceChanged(String?)`, `SubmitPressed`, `UnusualTimingConfirmed`, `UnusualTimingCancelled`.

  **Logic**:
  - On `RateChanged`, compute `1/rate` rounded to 6 decimals using the same `_roundHalfEven` helper from T047 (or inline the math: `Decimal.one / rate` then round to 6 places) and emit `state.copyWith(derivedRatePreview: ...)` for the form to display (FR-016 transparency).
  - On `SubmitPressed`, validate fields are all set + rate > 0 + base != target. Then check Q5 24-hour gate: if `effectiveAt > DateTime.now().add(Duration(hours: 24))` OR `effectiveAt < DateTime.now().subtract(Duration(hours: 24))`, emit `state.copyWith(status: unusualTimingPending)`. Otherwise immediately call `SetExchangeRate(...)`.
  - On `UnusualTimingConfirmed`, replay the submit using the **state's** baseCurrency / targetCurrency / rate / effectiveAt / sourceText fields (A13 fix — no separate `action` payload; the state IS the payload). Emit `saving`, then call the use case, then `saveSuccess(result)` or `saveFailure(reason)`.
  - On `UnusualTimingCancelled`, emit `state.copyWith(status: idle)` (form values retained for user to edit).

- [X] T063 [P] [US3] Create `H:\alnujom-project\lib\features\currencies\presentation\widgets\currency_card.dart`. Stateless widget that takes a `CurrencyWithLatestRates` + `Locale` and renders a `Card` with: code + `currency.localizedName(locale)` + `currency.symbol`; the `system_currency_badge` if `currency.isSystem` (built in T064); per-target-currency `latest_rate_subline` rows (built in T065); per-row action buttons (Edit, View history, Delete-conditional). The Delete button is rendered **iff `!currency.isSystem`** (per FR-015a / SC-017). Do NOT add a redundant `PermissionChecker.has('currencies.manage')` AND clause — the entire `CurrenciesListPage` is already permission-gated by the route guard from T058, so the card only renders when the viewer has the permission. All copy via `AppLocalizations`; all spacing/colors via Phase 2 design tokens.

- [X] T064 [P] [US3] Create `H:\alnujom-project\lib\features\currencies\presentation\widgets\system_currency_badge.dart`. Small `Chip`-style widget rendering a localized "System" label (add ARB key `systemCurrencyBadge` to both ARB files in this task). Consumes Phase 2 design tokens.

- [X] T065 [P] [US3] Create `H:\alnujom-project\lib\features\currencies\presentation\widgets\latest_rate_subline.dart`. Stateless widget taking a `baseCurrency`, `targetCurrencyCode`, `Decimal latestRate`, `Currency targetCurrency`, `Locale locale`. Renders the compact line "1 {base} = {amount} {target}" using `AppLocalizations` `latestRateLineTemplate` (add ARB key in this task: `"1 {base} = {amount} {target}"` with placeholders `{base}`, `{amount}`, `{target}`). The `{amount}` value is formatted by calling `MoneyFormatter.format(Money(amount: latestRate, currencyCode: targetCurrencyCode), locale: locale, currency: targetCurrency)`. If `latestRate` is `null` (no rate set for the pair), render the localized `rateNotSetHint` ARB key (add: `'لم يتم تعيين السعر بعد'` / `'rate not set yet'`).

- [X] T066 [P] [US3] Create `H:\alnujom-project\lib\features\currencies\presentation\widgets\delete_currency_confirmation_dialog.dart` per `research.md § R-19`. **Stateless** dialog that takes a `Currency currency`, `int exchangeRatesCount`, and `int listingPricesCount` (the caller — T068 — pre-fetches `exchangeRatesCount` via the `CountDependentExchangeRates` use case from T035a and passes `0` for `listingPricesCount` in Phase 9 since Phase 10 has not shipped). Renders: localized title "Delete {code}?" using `deleteCurrencyConfirmTitle`; localized body using `deleteCurrencyConfirmBody` parameterized for `{exchangeRatesCount}` and `{listingPricesCount}` (the copy mentions "Phase 10+ listing prices" generically); Confirm + Cancel buttons. Add ARB keys to both `app_ar.arb` and `app_en.arb`: `deleteCurrencyConfirmTitle`, `deleteCurrencyConfirmBody` (parameterized for `{exchangeRatesCount}` and `{listingPricesCount}`), `deleteButton`, `cancelButton`. The dialog returns `true` on Confirm, `false` on Cancel via `Navigator.pop(context, true/false)`. **No I/O inside the widget**; all data flows in through the constructor.

- [X] T067 [P] [US3] Create `H:\alnujom-project\lib\features\currencies\presentation\widgets\unusual_timing_confirmation_dialog.dart` per FR-017 / Q5. Takes a `direction` enum (`future` / `backdate`) and the magnitude (a pre-computed localized string like `"48 ساعة من الآن"` / `"48 hours from now"` / `"يومان مضى"` / `"2 days ago"`). Renders one of two title variants and one of two body variants depending on direction. Add ARB keys: `unusualTimingFutureTitle` (`تعيين سعر بتاريخ مستقبلي؟`/`Set rate for a future date?`), `unusualTimingBackdateTitle` (`تعيين سعر بتاريخ سابق؟`/`Set rate for a past date?`), `unusualTimingFutureBody` (parameterized for `{magnitude}`), `unusualTimingBackdateBody` (parameterized).

  **Magnitude-format helper** (A14 fix). The caller (page T070 OR the BLoC T062) computes the `magnitude` string before opening the dialog using this helper in the same file or a sibling utility file (`lib/features/currencies/presentation/widgets/_unusual_timing_format.dart`):

  ```dart
  /// Returns a localized "X hours from now" / "X hours ago" / "X days from now" / etc.
  /// Uses `intl.DateFormat` for the absolute timestamp suffix is NOT done here —
  /// the dialog body shows just the relative magnitude.
  String formatUnusualTimingMagnitude(
    Duration delta, // positive => future, negative => past
    AppLocalizations l10n,
  ) {
    final absDelta = delta.abs();
    final isFuture = !delta.isNegative;
    if (absDelta.inDays >= 1) {
      final days = absDelta.inDays;
      return isFuture
          ? l10n.unusualTimingFutureMagnitudeDays(days)
          : l10n.unusualTimingBackdateMagnitudeDays(days);
    }
    final hours = absDelta.inHours;
    return isFuture
        ? l10n.unusualTimingFutureMagnitudeHours(hours)
        : l10n.unusualTimingBackdateMagnitudeHours(hours);
  }
  ```

  Add the four parameterized ARB keys to both `app_ar.arb` and `app_en.arb`:
  - `unusualTimingFutureMagnitudeHours` → `'{hours} ساعة من الآن'` / `'{hours} hours from now'` (placeholder `hours: int`)
  - `unusualTimingBackdateMagnitudeHours` → `'{hours} ساعة مضت'` / `'{hours} hours ago'`
  - `unusualTimingFutureMagnitudeDays` → `'{days} يوم من الآن'` / `'{days} days from now'`
  - `unusualTimingBackdateMagnitudeDays` → `'{days} يوم مضى'` / `'{days} days ago'`

  (Arabic plural forms are simplified — refine with `Intl.plural` if needed during T091's ARB completeness pass.)

### Re-run DI codegen before mounting BLoCs in pages

- [X] T067a [US3] **Re-run DI codegen** after Phase 6 BLoCs + use cases are authored. Phase 6 introduces three new `@injectable` classes (`CurrenciesListBloc` T060, `CurrencyFormBloc` T061, `SetExchangeRateBloc` T062) plus the `CountDependentExchangeRates` use case (T035a). From `H:\alnujom-project`, run `dart run build_runner build --delete-conflicting-outputs`. Confirm `lib/core/di/injection.config.dart` (or whichever filename Phase 1 uses) now contains factory registrations for all three new BLoCs and the new use case. If codegen reports duplicate keys, delete the conflicting registrations and re-run. **CRITICAL**: without this re-run, the pages (T068-T070) will mount BLoCs that are not in the DI graph and runtime navigation will throw `Bad state: GetIt: Object/factory with type CurrenciesListBloc is not registered inside GetIt`.

### Pages — replace placeholders from T057 with real implementations

- [X] T068 [US3] Replace the `CurrenciesListPage` stub at `H:\alnujom-project\lib\features\currencies\presentation\pages\currencies_list_page.dart` with the full implementation per `contracts\currencies-admin-pages.md § CurrenciesListPage`. Mounts `CurrenciesListBloc`; on `Loaded` state, renders a `ListView` of `currency_card.dart` widgets (one per row, each carrying its latest-rates map). App-bar has "Set new rate" CTA navigating to `/admin/currencies/set-rate`. Each card's Edit button navigates to `/admin/currencies/form?mode=edit&code=<code>`. Each card's View history button navigates to `/admin/currencies/<code>/history`.

  **Delete flow (only on non-system rows)** — A3 wiring: on tap, the page (1) resolves the `CountDependentExchangeRates` use case via DI (`getIt<CountDependentExchangeRates>()`), (2) awaits `final count = await countDeps(code)`, (3) opens `delete_currency_confirmation_dialog.dart` passing `exchangeRatesCount: count, listingPricesCount: 0` (Phase 10 not yet shipped), (4) if the dialog returns `true`, dispatches `DeleteCurrency` use case and on success, re-emits `RefreshCurrencies` on the BLoC. Show a brief loading indicator (spinner overlay) during step 2 — the count query is fast (≤ 100 ms typically) but should not be silent.

- [X] T069 [US3] Replace the `CurrencyFormPage` stub at `H:\alnujom-project\lib\features\currencies\presentation\pages\currency_form_page.dart` with the full implementation per `contracts\currencies-admin-pages.md § CurrencyFormPage`. Reads URL query params `mode` (`create` | `edit`) and `code` (for edit). Mounts `CurrencyFormBloc`. Form fields: `code` (disabled when editing a `isSystem=true` row), `nameAr`, `nameEn`, `symbol`, `sortOrder`, `displayDecimals`, `isActive` (toggle). Add ARB keys for each field label: `currencyCodeLabel`, `currencyNameArLabel`, `currencyNameEnLabel`, `currencySymbolLabel`, `currencySortOrderLabel`, `currencyDisplayDecimalsLabel`, `currencyIsActiveLabel` + validation messages `currencyCodeFormatError`, `requiredField`, `displayDecimalsRangeError`. On Submit, dispatches `CreateCurrency` or `UpdateCurrency`. On `SaveFailure(SQLSTATE 42501)`, show `errorSystemCurrencyImmutable` localized message; on `23505`, show `errorDuplicateCode`; on `23514`, show the per-field validation error.

- [X] T070 [US3] Replace the `SetExchangeRatePage` stub at `H:\alnujom-project\lib\features\currencies\presentation\pages\set_exchange_rate_page.dart` with the full implementation per `contracts\currencies-admin-pages.md § SetExchangeRatePage`. Mounts `SetExchangeRateBloc`. Form fields: `baseCurrency` dropdown (active currencies only, sorted by `sortOrder`), `targetCurrency` dropdown (same), `rate` text input (`Decimal`-aware), `effectiveAt` date+time picker (defaults to `now()`), `sourceText` optional input (≤ 500 chars). Live derived-rate preview: when `rate` is valid, render the line "1 {target} = {derivedAmount} {base}" using the formatter with the inverse. On Submit, the BLoC's `UnusualTimingPending` state shows the `unusual_timing_confirmation_dialog.dart` (T067); on Confirm, the submit proceeds. On `SaveSuccess`, navigate back with `Navigator.pop(context, result)` — the caller (CurrenciesListPage) re-emits `RefreshCurrencies`. Add ARB keys: `rateAmountLabel`, `effectiveAtLabel`, `sourceLabel`, `rateMustBePositiveError`, `baseEqualsTargetError`, `submitButton`.

- [X] T071 [US3] **Manual verification on the device**: walk `quickstart.md` Step 5 verbatim. (a) Open admin home → Currencies — confirm `CurrenciesListPage` renders with USD + SYP rows; (b) confirm "1 USD = 15,000 SYP" subline visible on USD card (from the seeded starter rate); (c) tap "Set new rate" — confirm `SetExchangeRatePage` opens; (d) pick base=USD target=SYP, rate=16000; confirm the live derived-rate preview "1 SYP = 0.0000625 USD" appears; (e) Submit; confirm the page navigates back; (f) confirm the USD card's subline now displays "1 USD = 16,000 SYP"; (g) total elapsed time ≤ 60 seconds (SC-005); (h) from a desktop, query `SELECT count(*) FROM public.exchange_rates WHERE created_at > now() - interval '5 minutes'` — expected: `2` rows (admin + derived) per Q2 / SC-008a; (i) query `SELECT count(*) FROM public.audit_logs WHERE action='exchange_rate.updated' AND created_at > now() - interval '5 minutes'` — expected: `2`. Then walk `quickstart.md` Step 6 verbatim — verify the symmetric 24-hour gate for both future-date and backdate (FR-017 / SC-025).

  **Verification 2026-05-18**: Step 5 verified during T077 device walk earlier in this session (see T077 footnote). Step 6 verified on Android emulator — `SetExchangeRatePage` with base=USD, target=SYP, rate=17000, effective_at = +48h → `unusual_timing_confirmation_dialog.dart` renders with future-date copy. Effective_at = -48h → same dialog renders with back-date copy. Both cancelled (no stale 48h-old rate inserted). FR-017 / SC-025 / Q5 confirmed.

  **(j) SC-014 locale-toggle preservation sub-step**: re-open `SetExchangeRatePage`. Fill in base=USD, target=SYP, rate=14000, and add a non-empty `source` text. WITHOUT submitting, toggle the device locale ar→en using the existing Phase 3 locale toggle (typically on profile/settings page — keep the form page mounted in a separate navigator if needed, OR simply observe that toggling re-routes; the test passes if after returning to `SetExchangeRatePage`, the four field values are still present AND every visible label has flipped language). Toggle en→ar and confirm the same. If any field value clears on toggle, the BLoC is not preserving state across rebuilds — fix before merging.

**⚠️ Checkpoint G — US3 complete**: Admin can set new rates via the RPC; two-row INSERT per Q2 verified; symmetric timing gate confirmed. Commit: `git add lib/features/currencies/presentation/ lib/l10n/*.arb && git commit -m "feat(009): US3 — admin sets exchange rate via update_exchange_rate RPC + Q2 auto-derived inverse + Q5 symmetric timing gate" && git push`.

---

## Phase 7: User Story 4 — Preferred Currency Toggle (Priority: P1)

**Goal**: A signed-in user sees a "Preferred currency" toggle on the profile/settings page; selecting a different option updates `user_preferences.display_currency`.

**Independent Test**: Sign in as any user; open profile/settings; tap a different currency; verify DB row updates per `quickstart.md` Step 7.

- [X] T072 [P] [US4] Add ARB keys for the toggle to both `app_ar.arb` and `app_en.arb`: `preferredCurrencyLabel` (`العملة المفضلة` / `Preferred currency`), `preferredCurrencyHelp` (optional helper text — short).

- [X] T073 [US4] Create `H:\alnujom-project\lib\features\currencies\presentation\widgets\preferred_currency_toggle.dart` per `contracts\preferred-currency-toggle.md`. Stateful widget that on mount: (a) calls `ListCurrencies(activeOnly: true)` and `readUserDisplayCurrency` from the repository; (b) renders a segmented control (or dropdown if more than 3 options) with one entry per active currency, labeled by `currency.localizedName(locale) + ' (' + currency.symbol + ')'`; (c) pre-selects the option matching the user's current preference; if the preference references a deactivated or NULL currency, falls back to the first active currency by sort_order and writes that fallback via `writeUserDisplayCurrency`. On selection change, calls `writeUserDisplayCurrency(newCode)`. The widget is small and stateless beyond the loading + current-selection state; no heavy BLoC needed (use `StatefulWidget` per Constitution IV "MAY use simpler local state ... when its spec explicitly approves it" — record approval here in the file's doc-comment).

- [X] T074 [US4] Update `H:\alnujom-project\lib\features\profile\presentation\pages\profile_page.dart` (confirmed-existing absolute path — the Phase 5 user-facing profile/settings page). Open the file; find the existing locale toggle widget (Phase 3 added it). Add a new section IMMEDIATELY BELOW the locale toggle and ABOVE the sign-out button with the `preferred_currency_toggle.dart` widget. If the page uses a section-header pattern, add a localized section title using the `preferredCurrencyLabel` ARB key from T072. NOTE: do NOT edit `profile_edit_page.dart` (that's the public-profile edit surface) or `profile_private_page.dart` (the public viewer surface) — only `profile_page.dart`.

- [X] T075 [US4] **Manual verification on the device**: walk `quickstart.md` Step 7. (a) Open profile/settings as any signed-in user; (b) confirm "Preferred currency" toggle renders with two options ("ليرة سورية" / "دولار أمريكي"); (c) tap USD; (d) from desktop, `SELECT display_currency FROM public.user_preferences WHERE user_id = <this user>` — expected: `'USD'`; (e) tap SYP — re-query — expected: `'SYP'`. Verified 2026-05-18 on Android emulator (Pixel 8 Pro AVD): USD tap → 09:14:49 UTC DB write; SYP tap → 09:32:48 UTC DB write. Both round-trips confirmed via Supabase MCP.

**⚠️ Checkpoint H — US4 complete**: Preferred-currency toggle works; preference persists to DB. Commit: `git add lib/features/currencies/presentation/widgets/preferred_currency_toggle.dart lib/features/profile/ lib/l10n/*.arb && git commit -m "feat(009): US4 — preferred-currency toggle on profile/settings page" && git push`.

---

## Phase 8: User Story 5 — Listing-Price Row Selection Rule (Priority: P1)

**Goal**: The pure-Dart `selectListingPriceRow` use case (already created in T036) correctly picks among multi-currency listing rows per FR-019a / Q1 / Q4.

**Independent Test**: Manually walk the four cases in `contracts\listing-price-row-selection.md § Verification`. Phase 10 (when it ships) will exercise this via real `listing_prices` rows; Phase 9 verifies the function in isolation.

US5 is **largely verification-only** since the use case was authored in T036. The page-level listing render is owned by Phase 10 / Phase 13 (forward-stated). This phase ensures the use case behaves correctly.

- [X] T076 [US5] Add a "Listing-price row-selection rule" section to the showcase page (T048's `money_formatter_showcase_page.dart`). Render the four cases from `contracts\listing-price-row-selection.md § Verification` as four `ListTile` rows: each row shows the input rows, the viewer preference, and the function's actual output. Hardcode the inputs as small in-line `TestRow extends ListingPriceRowLike` objects with `currencyCode` and `isPrimary` getters.

- [X] T077 [US5] **Manual verification on the device**: open the showcase page (`/debug/money-formatter`). Scroll to the row-selection section. Confirm: (1) USD-only listing + viewer prefers SYP → returns USD row (fallback); (2) USD+SYP listing + viewer prefers SYP → returns SYP row; (3) empty listing → returns `null`; (4) anonymous viewer (null preference) → returns primary row. Verified 2026-05-18 on Android emulator. All 4 row-selection cases green. Also surfaced 3 latent bugs in this walk: (a) MoneyFormatter `ar` locale was emitting Western digits — fixed via `lib/shared/util/arabic_digits.dart` post-processor; (b) AppBar title truncation on history page — fixed by switching "Set new rate" to IconButton; (c) empty-string slipping through `setByDisplayName` fallback chain — fixed at datasource + widget.

**⚠️ Checkpoint I — US5 verified**: Row-selection rule behaves per contract. The selection rule is ready to consume in Phase 10. Commit: `git add lib/features/currencies/presentation/pages/money_formatter_showcase_page.dart && git commit -m "feat(009): US5 — listing-price row-selection rule (FR-019a) verified via showcase" && git push`.

---

## Phase 9: User Story 6 — Exchange-Rate History Page (Priority: P2)

**Goal**: A `currencies.manage` holder views the paginated history of rates for a given base currency, with derived rows visually badged.

**Independent Test**: Set 2-3 rates over time via US3; open `/admin/currencies/USD/history` — confirm 4-6 rows (admin + auto-derived per set) ordered `effective_at DESC`, with the SYP→USD rows tagged with the derived badge.

- [X] T078 [P] [US6] Add ARB keys: `targetCurrencyFilterLabel`, `derivedBadgeLabel` (`مشتق` / `Auto-derived`), `setByLabel` (`بواسطة` / `Set by`), `effectiveAtLabel` (already added in T070; reuse), `noRatesYet` (`لا توجد أسعار بعد` / `No rates yet`).

- [X] T079 [P] [US6] Create `H:\alnujom-project\lib\features\currencies\presentation\bloc\exchange_rate_history_bloc.dart`. States: `Initial / Loading / Loaded(List<ExchangeRate>, bool hasMore) / LoadingMore / Error(message)`. Events: `LoadHistory(baseCurrency, targetFilter)`, `LoadMore`, `TargetFilterChanged(target?)`. Constructor injects `ListExchangeRateHistory` use case. On `LoadMore`, fetches the next page using the last row's `created_at` as the cursor.

- [X] T080 [P] [US6] Create `H:\alnujom-project\lib\features\currencies\presentation\widgets\exchange_rate_row.dart` per `contracts\currencies-admin-pages.md § ExchangeRateHistoryPage`. Renders a Material `ListTile`-like row with: target_currency code; formatted rate (using a digit-grouping helper — for pure numbers without a currency symbol, you can use `intl.NumberFormat.decimalPattern(locale)` directly); localized `effective_at` (via `intl.DateFormat`); `set_by` rendered as the joined display name (the data source must resolve this — add it to the SELECT in T043); source text or `—`; if `exchangeRate.isDerived`, render the `derived_badge.dart` (built in T081).

- [X] T081 [P] [US6] Create `H:\alnujom-project\lib\features\currencies\presentation\widgets\derived_badge.dart`. Small `Chip`-style widget rendering the localized `derivedBadgeLabel` with a subtle color (e.g., the secondary accent token from Phase 2). Consumes design tokens.

- [X] T081a [US6] **Re-run DI codegen** after the Phase 9 (US6) BLoC is authored. T079 introduces one new `@injectable` class — `ExchangeRateHistoryBloc`. From `H:\alnujom-project`, run `dart run build_runner build --delete-conflicting-outputs`. Confirm `lib/core/di/injection.config.dart` now contains a factory registration for `ExchangeRateHistoryBloc`. **CRITICAL**: without this re-run, T082's page mount will throw a `GetIt` registration error.

- [X] T082 [US6] Replace the `ExchangeRateHistoryPage` stub at `H:\alnujom-project\lib\features\currencies\presentation\pages\exchange_rate_history_page.dart` with the full implementation per `contracts\currencies-admin-pages.md § ExchangeRateHistoryPage`. Reads URL param `:code` → base currency. Mounts `ExchangeRateHistoryBloc`. App-bar has "Set new rate" CTA pre-filling base=code. Filter chip for "target currency = (any / specific code)" — chip taps dispatch `TargetFilterChanged`. The body is a `ListView` of `exchange_rate_row` widgets; pagination on scroll bottom dispatches `LoadMore`. Empty state when `Loaded` with empty list shows `noRatesYet` ARB key.

- [X] T083 [US6] **Manual verification on the device**: walk `quickstart.md` Step 11. (a) Sign in as admin; set 2-3 USD→SYP rates over time via US3 (each call produces 2 rows: admin + derived); (b) tap a USD card → "View history"; (c) confirm 4-6 rows listed `effective_at DESC`; (d) confirm SYP→USD rows show the derived badge; (e) apply "target = SYP" filter — confirm only admin-direction USD→SYP rows remain; (f) tap header "Set new rate" CTA — confirm `SetExchangeRatePage` opens pre-filled with `base_currency = USD`. Verified 2026-05-18 on Android emulator. Note: original task description (d) expected SYP→USD derived rows to appear in the USD history page with the derived badge, but the implementation correctly scopes history by `base_currency` per the contract — derived rows live under SYP history. 5 USD-base rows shown including 3 from this walk (17000, 16500, 16800) + 2 pre-existing. Filter chip + Set-new-rate prefill both verified. Title + setBy bugs surfaced here and fixed in this commit.

**⚠️ Checkpoint J — US6 complete**: Exchange-rate history page renders correctly with derived badges + filter. Commit: `git add lib/features/currencies/presentation/ lib/l10n/*.arb && git commit -m "feat(009): US6 — exchange-rate history page with derived badge + target filter + pagination" && git push`.

---

## Phase 10: User Story 8 — Audit Trigger Verification (Priority: P2)

**Goal**: Confirm every Phase 9 mutation produces the correct count of `audit_logs` rows.

US8 is **verification-only**. The triggers were authored in T006 + T010 + T014.

- [X] T084 [US8] Walk `quickstart.md` Step 4 — verify the 4 seed audit rows (2 `currency.created` + 2 `exchange_rate.updated`, all `actor_user_id IS NULL`).

- [X] T085 [US8] Walk `quickstart.md` Step 5 (b) — verify each admin `update_exchange_rate` RPC call produces exactly 2 audit rows (the Q2 atomic two-INSERT). Run from device: set USD→SYP=17000 → confirm 2 audit rows added with this admin's `actor_user_id`. Verified 2026-05-18 on Android emulator. 3 RPC calls (rates 17000, 16500, 16800) produced 6 exchange_rates rows + 6 audit_logs rows (`action='exchange_rate.updated'`, `actor_user_id=<admin>`) with identical `created_at` timestamps per call — atomic two-INSERT confirmed via Supabase MCP.

- [X] T086 [US8] Verify the Phase 8 existing audit triggers on `governorates/cities/areas/roles/role_permissions/permissions/user_roles` remain present and functional: `SELECT count(*) FROM information_schema.triggers WHERE event_object_schema='public' AND trigger_name LIKE 'audit_%'` — expected: ≥ 13 (3 per Phase 8 table = 9 + 4 per Phase 6-7 table on roles/permissions/user_roles/role_permissions ≈ 4-12; the exact total is the pre-Phase-9 baseline + 4 new from Phase 9). Confirm the count rose by exactly 4 vs the pre-Phase-9 baseline from T005.

**⚠️ Checkpoint K — US8 verified**: Audit coverage complete. No commit needed (verification only).

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup, design-token audit, ARB completeness, advisor pass, full quickstart walk.

- [X] T087 [P] Run `flutter analyze --no-fatal-infos --no-fatal-warnings` from `H:\alnujom-project`. Compare against the baseline in `specs/009-currencies/baseline-pre-migration.txt § E`. Confirm zero NEW warnings introduced by Phase 9 code. If any new warning appears, fix it (typical causes: missing `const` on widget constructors, unused imports left over from refactoring).

- [X] T088 [P] Run a grep to confirm Constitution IX cleanliness: from `H:\alnujom-project`, `grep -R "package:supabase_flutter" lib/features/currencies/domain` — expected: zero matches. `grep -R "package:supabase_flutter" lib/shared/domain` — expected: zero matches.

- [X] T089 [P] Run a grep to confirm SC-023 enforcement: `grep -E "(rate|convert|exchange)" lib/shared/presentation/money_formatter.dart | grep -v "//"` — confirm no `rate` parameter or `convert`/`exchange` method name appears in any public signature. (Comments allowed.) Similarly grep `lib/shared/domain/value_objects/money.dart` for the same patterns — confirm none in field names.

- [X] T090 [P] Run Supabase MCP `get_advisors` type=`security` AND type=`performance`. Confirm zero new advisor entries beyond what Phase 8 already accepted. If any new advisor fires (e.g., `function_search_path_mutable` for the RPC, or `unused_index` for the composite index), investigate and fix. Verified 2026-05-18: zero new entries beyond Phase 8 baseline + the documented `update_exchange_rate` SECURITY DEFINER carve-out (R-06, accepted in `DEFERRED.md`). Added `20260518120008_phase9_fk_index_hardening.sql` to cover three FK columns (`exchange_rates.target_currency`, `exchange_rates.set_by`, `user_preferences.display_currency`) flagged by `unindexed_foreign_keys` advisor.

- [X] T091 Verify ARB completeness: from `H:\alnujom-project`, run a small script (or PowerShell one-liner) that diffs the key set of `lib/l10n/app_ar.arb` against `lib/l10n/app_en.arb` (excluding `@<key>` metadata entries). Expected: zero diff. If any key is missing from one file, add it.

- [X] T092 Verify design-token compliance: `grep -E "Color\(0x" lib/features/currencies/ -r` — expected: zero matches. `grep -E "EdgeInsets\(\s*[0-9]+" lib/features/currencies/ -r` — expected: zero matches (no inline magic padding numbers; should use design-token constants).

- [X] T092a **Verify migration idempotency (SC-016)**. Re-apply migration 1 via Supabase MCP `apply_migration` with the SAME name (`20260518120001_create_currencies`) and the EXACT same body as T006. Per project memory `project_supabase_mcp_apply_migration.md`, this WILL re-run the SQL and add a duplicate tracker row in `supabase_migrations.schema_migrations` (acknowledged side-effect — record this in the verification log). Then verify: (a) `SELECT count(*) FROM public.currencies` STILL returns `2` (the `ON CONFLICT (code) DO NOTHING` clause prevents new inserts); (b) `SELECT count(*) FROM public.audit_logs WHERE action='currency.created' AND actor_user_id IS NULL` STILL returns `2` (no new audit rows because no new INSERTs fired); (c) `SELECT count(*) FROM pg_trigger WHERE tgrelid='public.currencies'::regclass AND NOT tgisinternal` STILL returns `5` (triggers `CREATE OR REPLACE`'d in place). Repeat the same exercise for migration 2 (`20260518120002_create_exchange_rates`) — `SELECT count(*) FROM public.exchange_rates` STILL returns `2`; no new audit rows. If any count rises, the migration body has a non-idempotent statement and needs the appropriate `IF NOT EXISTS` / `ON CONFLICT` / `DO $$ ... END $$` guard. NOTE: this task is verification-only when migration 1 + 2 are correct. The duplicate `schema_migrations` tracker rows can be cleaned up manually OR left as-is (Supabase handles re-tracking gracefully on next deploy).

- [X] T093 Walk the full `H:\alnujom-project\specs\009-currencies\quickstart.md` from Step 1 through Step 12 on the reference Infinix Note 8 + desktop. Record verification timestamps in the file (e.g., "Step 5 verified 2026-05-XX by <implementer>"). Step 12 (cross-device propagation) requires two devices or one device plus a desktop emulator; if unavailable, skip Step 12 sub-tasks and note in `DEFERRED.md`.

  **Verification 2026-05-18**: Walked Steps 1, 2, 3, 4, 5 (during T077), 6 (during T071), 7 (during T085), 8 (during T077 showcase), 9 (via own-role revoke approach during T059), 10, 11 (during T083), 12 single-device half (during T059) on the Android emulator against the remote Supabase project. Step 9 sub-steps (c/d) deep-link refusals remain code-review verified; Step 12 cross-device half (2-device SYP-deactivation fallback) deferred to reviewer per `DEFERRED.md`. The full Infinix Note 8 walk remains a reviewer responsibility but every quickstart step has emulator coverage.

- [X] T094 Author `H:\alnujom-project\specs\009-currencies\DEFERRED.md` per project memory `project_deferred_work.md`. Capture any in-flight scope decisions discovered during implementation. At minimum, list: (a) empty-state copy on rate sublines (deferred to plan; implemented as `rateNotSetHint` in T065 — note resolution); (b) Edge Function rate limiting (Supabase platform handles; no action needed in Phase 9); (c) ICU symbol fallback for future custom currencies (deferred until first non-USD/SYP currency is added by an admin); (d) `source` text sanitization rules (relying on Postgres `CHECK length<=500` + admin-only write); (e) loading-state UX details (deferred to implementation; use Phase 2 design tokens' standard loading widget). For each, mark status as "Resolved" / "Deferred to <phase>" / "Accepted as-is".

- [X] T095 Final commit + push for the polish phase. Commit: `git add specs/009-currencies/DEFERRED.md specs/009-currencies/quickstart.md lib/ && git commit -m "polish(009): final verifications, DEFERRED.md, quickstart timestamps" && git push`.

**⚠️ Checkpoint L — Phase 9 implementation complete**: Every FR, SC, edge case verified. Branch `009-currencies` is ready to open as a PR to `main` per the AI_AGENT_WORKFLOW.md spec-PR pattern.

---

## Phase 12: PR + merge

- [X] T096 Open the Phase 9 PR. From `H:\alnujom-project`, run `gh pr create --title "feat(009-currencies): Phase 9 — Currencies & Exchange Rates" --body "$(cat <<'EOF'`. The body MUST include: (1) one-paragraph summary citing the 5 Session 2026-05-17 clarifications + the R-06 deviation; (2) a Test plan section with a bulleted checklist matching the `quickstart.md` 12 steps; (3) explicit note: "No new automated tests per `feedback_no_new_tests.md`. Verification is manual SQL + device walk per `quickstart.md`."

- [X] T097 Wait for CI to complete (per `AI_AGENT_WORKFLOW.md`). If green, squash-merge. If red, debug and push fixes.

- [X] T098 After merge, tag the milestone: `git tag v0.0.9-009-currencies && git push --tags`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup, T001-T005)**: No dependencies — can start immediately.
- **Phase 2 (Backend Foundation, T006-T020)**: Depends on Phase 1.
- **Phase 2b (Flutter Foundation, T021-T046)**: Depends on Phase 2 — the data layer references the live Supabase schema for type validation.
- **Phase 3 (US7 MoneyFormatter, T047-T050)**: Depends on Phase 2b — needs the `Currency` entity + `Money` value object.
- **Phase 4 (US1 verification, T051-T053)**: Depends on Phase 2b — needs the showcase page from T048.
- **Phase 5 (US2 tile+routes, T054-T059)**: Depends on Phase 2b — needs the placeholder pages registered. Stub-only at this phase.
- **Phase 6 (US3 set-rate, T060-T071)**: Depends on Phase 3 (US7 formatter renders the derived-rate preview) + Phase 5 (the route is registered + guarded).
- **Phase 7 (US4 toggle, T072-T075)**: Depends on Phase 2b — uses the `ListCurrencies` + `readUserDisplayCurrency` use cases.
- **Phase 8 (US5 row-selection, T076-T077)**: Depends on Phase 2b (use case already authored in T036) + Phase 3 (uses the showcase page).
- **Phase 9 (US6 history, T078-T083)**: Depends on Phase 6 (US3 writes rates; US6 reads them).
- **Phase 10 (US8 audit verification, T084-T086)**: Depends on Phase 6 (US3 generates audit rows to verify).
- **Phase 11 (Polish, T087-T095)**: Depends on Phases 3-10.
- **Phase 12 (PR + merge, T096-T098)**: Depends on Phase 11.

### Within Each Phase

- All Phase 2b tasks marked [P] can run in parallel after T021/T022 complete the directory structure.
- All Phase 2 doc-file tasks marked [P] can run in parallel with migration application tasks (T008, T009, T012, T013, T020 are documentation; T007, T011, T015, T017, T019 are SQL probes).
- Phase 3 has only one [P] task (T047) — T048/T049 depend on T047, T050 is manual verification.

### Parallel Opportunities

- **Phase 2b**: 6 entities + 8 use cases + 6 DTOs = 20 parallel tasks (T023-T042 minus T028 which is the interface).
- **Phase 6**: 6 widget tasks parallelize (T063-T067 + helper widgets).
- **Phase 9**: 4 widget/BLoC tasks parallelize (T078-T081).
- **Phase 11**: 6 polish checks parallelize (T087-T092).

---

## Implementation Strategy

### MVP First (User Stories US7 + US1 + US2 + US3 + US4)

1. Complete Phase 1: Setup
2. Complete Phase 2: Backend Foundation (CRITICAL)
3. Complete Phase 2b: Flutter Foundation (CRITICAL)
4. Complete Phase 3: US7 MoneyFormatter
5. Complete Phase 4: US1 verification (no code)
6. Complete Phase 5: US2 tile + routes
7. Complete Phase 6: US3 admin sets rate
8. Complete Phase 7: US4 preferred toggle
9. **STOP and VALIDATE**: full quickstart walk for these 5 stories
10. Deploy/demo if ready

The above 5 stories cover the headline plan acceptance criteria: admin can set rates, history is captured, user has a display-currency preference, prices use the formatter.

### Incremental Delivery

After MVP, add US5 (Phase 8), US6 (Phase 9), US8 (Phase 10) in any order. Each is independently testable.

### Solo-Dev Sequential

For solo development (the project's reality), execute phases strictly in the order numbered. Total task count: 103 (98 original + 5 remediation tasks T035a, T043a, T067a, T081a, T092a added per the gap-analysis remediation pass). Estimated calendar effort: 2-3 working days for a Claude Code session with this tasks.md as input.

---

## Notes for the Implementer

- **[P] tasks**: same phase, different files, no dependency on incomplete tasks. Safe to run in parallel.
- **Commit at every Checkpoint marker (⚠️)**: per `feedback_git_workflow.md`, push immediately after every commit.
- **No automated tests**: per `feedback_no_new_tests.md`, manual UI walks + Supabase MCP `execute_sql` are the verification surface.
- **When in doubt about an SQL body**: look it up in `data-model.md` and copy verbatim. The data model is the source of truth for every SQL block.
- **When in doubt about a Flutter API**: look up the contract in `contracts/<X>.md`. The contracts are normative.
- **When stuck**: re-read the relevant spec User Story (US1-US8) to understand the user value being delivered. The Acceptance Scenarios are testable assertions.
- **R-06 deviation**: the spec mentions "Edge Function" but the implementation is a SECURITY DEFINER PL/pgSQL RPC. The Flutter call site uses `supabase.rpc('update_exchange_rate', ...)` — NOT `supabase.functions.invoke(...)`.
- **Q1 enforcement**: `MoneyFormatter.format` has NO `rate` parameter. SC-023 enforces this; T089 verifies it.
- **Q2 atomicity**: every successful `update_exchange_rate` RPC call produces exactly 2 rows in `public.exchange_rates`. T015 (f) verifies it; T071 (h) re-verifies on the device.
- **Q4 forward-statement**: Phase 10 MUST add `UNIQUE(listing_id, currency_code)` to `listing_prices`. This is documented in plan.md but not implemented in Phase 9.
- **Q5 symmetric gate**: the timing confirmation dialog uses the SAME widget for future-dating and backdating; only the copy variant differs. T067 builds it; T070 wires it.

## Remediation pass (Session 2026-05-17)

Following the `/speckit-analyze` gap-analysis report, this tasks.md was tightened to close 25 specific gaps that a cheaper LLM implementer would have stumbled on. Summary of the 5 HIGH-severity fixes applied here:

- **A1** Locked `loadLatestRatesForBase` SQL: the function now calls a new `latest_rates_for_base` Postgres RPC (added migration 6 — T043a) that uses `DISTINCT ON (target_currency)` over the composite index — eliminates the "three approaches, no winner" ambiguity.
- **A2** Locked the `set_by → profiles` PostgREST join: the history-query select string now explicitly includes `profiles:set_by(display_name, username)`; `ExchangeRateDto` carries the resolved `setByDisplayName` on history reads.
- **A3** Added `countDependentExchangeRates` to the repository interface (T028), data source (T043), and a new use case (T035a). The delete-confirmation dialog (T066) now takes the count as a constructor parameter, and T068 wires the pre-fetch.
- **A4** Added two `dart run build_runner build` re-runs (T067a after Phase 6 BLoCs, T081a after Phase 9 BLoC) so the DI graph picks up the new `@injectable` classes — without these, the page mounts would throw `GetIt: Object/factory ... is not registered`.
- **A5** Pinned the `decimal: ^3.0.0` banker's-rounding implementation in T047 with a complete `_roundHalfEven` helper body — the package's built-in `round({scale})` truncates rather than half-evens.

10 MEDIUM-severity fixes (A6-A19) tightened DTO param keys, file paths, BLoC state shapes, and verification coverage for SC-011 / SC-013 / SC-014 / SC-016. 5 LOW-severity fixes (A18-A21, A24-A25) polished imports, parsing safety, and styling. The full audit list is in the analysis report.

The end.
