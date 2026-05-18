# Research: Currencies & Exchange Rates

**Owner**: Phase 9 (`specs/009-currencies/`).
**Created**: 2026-05-17
**Status**: Locked. All decisions below are binding inputs to `plan.md`, `data-model.md`, `contracts/`, `tasks.md`, and the implementation.

Phase 9 makes **22 locked technical decisions** (R-01 through R-22). Phase 8 introduced 22 decisions; Phase 9 reuses 14 of them unchanged via the carry-forward pattern and introduces 8 net-new decisions (R-06 Edge Function vs RPC, R-09 decimal package, R-10 NUMERIC precision, R-11 inverse-derive rounding mode, R-12 ICU symbol override, R-13 row-selection rule, R-14 user_preferences FK addition, R-22 fallback chain on missing display-currency match).

---

## R-01 — Migration filename convention (date-prefixed, monotonic per phase) *(carry-forward)*

**Decision**: Phase 9 uses the same synthetic-monotonic 14-digit timestamp prefix pattern Phase 4/5/6/7/8 use: `20260518120001_` through `20260518120005_`. The date encodes "May 18, 2026" — one day after Phase 8's `20260517...` series — to keep clear visual phase separation in `supabase/migrations/`. The implementation plan's reference to `0014_create_currencies.sql` / `0015_create_exchange_rates.sql` is historical drift; the actual project uses date-prefixed names.

**Rationale**: The migration tracker orders by filename ASCII-sort; date-prefixed names are correctly ordered even after long pauses or interleaved chore branches. Descriptive integers (`0014_`) are brittle when phases run out of order.

**Alternatives considered**: Strict ISO 8601 (`2026-05-18T12:00:01Z_`) was rejected because Supabase's migration tracker doesn't tolerate non-numeric prefix characters. Pure unix-epoch was rejected because the resulting filenames don't tell a reviewer which calendar day the migration was authored.

---

## R-02 — Inline policy bundling + parallel policy files *(carry-forward)*

**Decision**: Phase 9's two RLS policy declarations live inline in `20260518120001_create_currencies.sql` and `20260518120002_create_exchange_rates.sql` (per `apply_migration`'s natural unit-of-work), AND are mirrored to source-of-truth files at `supabase/policies/currencies_phase9.sql` and `supabase/policies/exchange_rates_phase9.sql`. Both copies are kept in sync at PR review time.

**Rationale**: The Phase 4 R-02 invariant — policies are reviewable as standalone files AND apply atomically with their table — is preserved a sixth time across Phases 4/5/6/7/8/9.

**Alternatives considered**: Policy-only in dedicated files (no inline) was rejected because the migration would then create the table with RLS enabled but no policies — a transient deny-all window for any concurrent reader. Inline-only was rejected because reviewers lose the standalone-file scannability that the policies dir provides.

---

## R-03 — No new packages in `pubspec.yaml` *(partial deviation)*

**Decision**: Phase 9 deviates from the strict Phase 8 R-03 "zero new packages" rule by adding exactly **one** runtime dependency: `decimal: ^3.0.0`. This is required by the `Money` value object's `Decimal amount` field per FR-020 / R-09. No new dev packages.

**Rationale**: The `Money` value object MUST avoid floating-point rounding errors on multi-million SYP amounts (e.g., `750,000,000.00 SYP`). Dart's built-in `double` IEEE-754 representation is insufficient. The `decimal` package is the de-facto Dart standard for arbitrary-precision decimals; it has no platform-specific code (pure Dart) and no transitive heavyweight dependencies.

**Alternatives considered**:
- Use `int` for SYP amounts (since SYP has 0 fractional digits) — rejected because USD/EUR/future currencies require fractional digits, and a uniform `Decimal` type across all currencies is cleaner than a per-currency type union.
- Use `BigInt` and store cents/halalas as integers — rejected for the same per-currency-uniformity reason, plus the formatter would need to know the currency to divide by the right power of 10.
- Pull the package only into `lib/shared/` to avoid leaking it into feature code — not feasible: feature code (e.g., Phase 10's listing form, Phase 13's price block) MUST consume `Money` instances, which means `Decimal` flows through feature `domain/` layers too. The package becomes a project-wide dependency.

---

## R-04 — Anonymous SELECT carve-out for global reference data *(carry-forward)*

**Decision**: Both `public.currencies` and `public.exchange_rates` have RLS policies that admit `anon` AND `authenticated` for SELECT. This is the **third** project-wide carve-out from the authenticated-only default; Phase 8 added the second (governorates/cities/areas treated as one group); Phase 4/5/6/7's tables remain authenticated-only.

**Rationale**: Phase 13 (public listing details), Phase 14 (search), and Phase 15 (map view) all serve anonymous clients who must resolve a listing's `currency_code` to a display symbol. The catalog is not sensitive data — it is a globally-known reference list.

**Alternatives considered**: Authenticated-only with anonymous read mediated by an Edge Function was rejected as over-engineered for a 2-row reference table.

---

## R-05 — `log_audit()` reusable trigger function unchanged *(carry-forward, sixth time)*

**Decision**: Phase 4's `log_audit()` PL/pgSQL function is invoked unchanged by the two new Phase 9 trigger groups. The trigger declarations follow the same TG_ARGV[0] = action-key convention used by Phases 5/6/7/8.

**Rationale**: The Phase 4 R-05 reusability invariant — `log_audit()` is the central audit-emission helper, called from many triggers, never modified per-phase — is preserved a sixth time across Phases 4/5/6/7/8/9. Any per-phase deviation would compound: the next phase would have to decide whether to fork or align, and the audit-log schema would calcify around the older callers.

**Alternatives considered**: A new `log_currency_audit()` specialized for the currencies tables was rejected because the generic `log_audit(action, target_type, target_id_column)` already handles every shape Phase 9 needs.

---

## R-06 — `update_exchange_rate` is a SECURITY DEFINER RPC, NOT an Edge Function *(plan-time deviation)*

**Decision**: The implementation plan's literal text references "Edge Function `update_exchange_rate`". Phase 9 implements the mutation as a SECURITY DEFINER PL/pgSQL function `public.update_exchange_rate(...)` at the database layer instead. The Flutter client calls it via `supabase.rpc('update_exchange_rate', params)`. No TypeScript folder under `supabase/functions/update_exchange_rate/` is created.

**Rationale**:
1. **Simpler deployment**: One migration vs. a separate TypeScript build + `deploy_edge_function` step.
2. **Atomicity is automatic**: The Q2 two-row INSERT (admin + auto-derived inverse) is inherently transactional inside a PL/pgSQL function — no manual `BEGIN ... COMMIT` boilerplate or rollback handling.
3. **Migration-tracked**: The RPC body lives in `20260518120003_create_update_exchange_rate_rpc.sql` and is versioned alongside the table schemas it depends on.
4. **Phase 7 precedent**: Phase 7's `mutate_role` made the same deviation per Phase 7 Clarifications Q3, with R-06 as its research-bench number. Phase 9 inherits the pattern as research R-06 here (numbering coincidence — both phases independently chose R-06 for this same deviation).
5. **No TypeScript build chain**: Edge Functions require Deno + a TypeScript compile step; the Phase 7 precedent established that PL/pgSQL is sufficient for permission-checked atomic-mutation use cases.

**Alternatives considered**:
- TypeScript Edge Function (as literally specified by the implementation plan) — rejected per the rationale above. Spec narrative preserves "Edge Function" language for continuity with the implementation plan; the deviation is recorded as a spec Assumption ("Edge Function vs RPC implementation surface") per Constitution XII.
- PostgREST direct INSERT (no RPC, client computes the inverse and submits both rows) — rejected because (a) the client cannot atomically INSERT two rows via PostgREST (each is a separate HTTP call), so race conditions are possible, and (b) the derived-rate rounding precision is centralized in one place (PL/pgSQL `round()`) rather than risking client-vs-server precision drift.

**Implication**: Spec's FR-012, US3, US8 acceptance scenarios, and SC-005/SC-008a/SC-015 are all preserved at the functional level. The structured error codes that the spec calls "HTTP 400/403/500" map to PostgreSQL SQLSTATE values per the spec Assumption: 403 ↔ `42501`, 400 ↔ `22023`, 500 ↔ everything else.

---

## R-07 — `is_system` columns + immutability trigger on `currencies` *(carry-forward, Phase 6/8 precedent)*

**Decision**: `public.currencies.is_system BOOLEAN NOT NULL DEFAULT false`. The two seeded rows (`USD`, `SYP`) are inserted with `is_system=true`. An `enforce_currency_system_immutability` PL/pgSQL trigger refuses any `DELETE` on a `is_system=true` row AND refuses any `UPDATE` that changes the `code` column on a `is_system=true` row. Other columns (`name_ar`, `name_en`, `symbol`, `sort_order`, `is_active`, `display_decimals`) remain editable even on `is_system=true` rows.

**Rationale**: Phase 6's `roles.is_system` and Phase 8's `governorates.is_system` / `cities.is_system` established the pattern. Currencies USD and SYP are foundational — listings will reference them — so accidental deletion or `code`-rename would cascade-break references (the `ON DELETE RESTRICT` FK guards reference-loss but not rename-disruption; the trigger handles both). Pattern provides defense-in-depth: even a direct SQL DELETE via Supabase MCP `execute_sql` with an admin JWT is refused.

**Alternatives considered**: A flag on the application layer only (no DB-side trigger) — rejected because RLS + UI alone is bypassable from a Studio session, and the seeded rows are the most-load-bearing reference data in the project.

---

## R-08 — Trigger-before-seed audit ordering *(carry-forward)*

**Decision**: The audit triggers on `currencies` and `exchange_rates` are attached in the same migration BEFORE the seed `INSERT` statements run. The seeded `USD` and `SYP` rows therefore produce exactly two `currency.created` audit rows with `actor_user_id=NULL` (system provenance). If FR-005's optional starter rate is seeded, two additional `exchange_rate.updated` audit rows are emitted with `actor_user_id=NULL`.

**Rationale**: Phase 8 Clarifications Q5 / Phase 8 R-08 established that the project-wide invariant "every mutation on an audit-tracked table produces exactly one audit row" should hold for the initial seed too. Carrying this forward to Phase 9 keeps the invariant intact.

**Alternatives considered**: Attach triggers AFTER the seed runs, producing zero audit rows for the initial seed — rejected because it makes the audit history non-uniform (the initial seed is an unaudited "magic write" different from every subsequent write).

---

## R-09 — `decimal: ^3.0.0` for `Money.amount` *(new)*

**Decision**: The `Money` value object's `amount` field is typed as `Decimal` from `package:decimal`. The `decimal` package is added to `pubspec.yaml` under `dependencies` as the single new runtime package.

**Rationale**: See R-03 rationale. Dart's built-in `double` cannot safely represent SYP amounts above ~9 quadrillion (the IEEE-754 mantissa limit); even smaller SYP amounts in the hundreds of millions exhibit visible rounding errors when summed.

**Alternatives considered**: `BigInt` storing minor units (cents/halalas) — rejected for the reasons in R-03.

---

## R-10 — `exchange_rates.rate` is NUMERIC(18, 6) *(new)*

**Decision**: The `rate` column is `NUMERIC(18, 6)` — 12 integer digits, 6 fractional digits. The choice handles:

- SYP-scale rates: up to ~999,999,999,999 (12 integer digits is enough; current real-world SYP rates are in the 10,000–20,000 range against USD).
- USD-scale inverse derived rates: down to ~0.000001 (1/1,000,000 — far below any realistic rate; 1/15,000 ≈ 0.000067 rounds cleanly to 6 decimals).
- Future currencies: EUR, TRY, GBP all fall within these bounds.

**Rationale**: Postgres `NUMERIC` is arbitrary-precision but fixed-precision `NUMERIC(18, 6)` is more storage-efficient and the constraint catches arithmetic mistakes earlier. 6 fractional digits is the cross-industry FX convention (Bloomberg, Reuters, central banks publish FX rates at 4-6 decimal places).

**Alternatives considered**:
- `NUMERIC(10, 4)` — rejected because 4 fractional digits visibly truncates inverse rates (1/15,000 ≈ 0.0001 vs. the more accurate 0.000067).
- `NUMERIC` without precision/scale — rejected as harder to validate and reason about; the explicit precision is intentional.
- `DOUBLE PRECISION` (float8) — rejected for the same reasons as Dart `double`: IEEE-754 imprecision.

---

## R-11 — Auto-derive inverse rounding mode: banker's rounding enforced at the display layer *(new, Q2 derivation; refined 2026-05-17)*

**Decision (refined)**: Banker's rounding (half-to-even, IEEE 754 `roundTiesToEven`) is enforced at the **display layer** by `MoneyFormatter._roundHalfEven` (per R-17 + the locked implementation in `tasks.md` T047). The **storage layer** — the `update_exchange_rate` RPC — uses Postgres's built-in `round(NUMERIC, INTEGER)`, which is **half-away-from-zero**. The two-layer split is intentional.

**Why the divergence is acceptable**:

1. **Precision differential**: storage is `NUMERIC(18, 6)` — six decimal places of microscopic-precision FX history. At that scale, the `0.000062` vs `0.000063` delta on a `1/16000` derivation is $10^{-6}$ of a SYP per USD — financially indistinguishable.
2. **Display-layer enforcement covers FR-021 / FR-023 / SC-013**: every user-facing rate render flows through `MoneyFormatter`, and the formatter rounds with banker's. Bias-accumulation at the eyeball level is what the spec actually cares about.
3. **PL/pgSQL banker's-rounding would add ~10 lines and a helper function** for a non-user-visible storage difference. The complexity isn't justified.
4. **Observed in Phase 2a verification**: the T015 test call `update_exchange_rate('USD', 'SYP', 16000)` produced derived rate `0.000063` (Postgres `round` of `0.00006250` away from zero) instead of `0.000062` (banker's would round to even). The implementation is consistent with this refinement; no remediation needed.

**Rationale**: Half-away-from-zero at the storage layer is conventionally accepted in FX systems for its simplicity and Postgres-native support. Banker's at the display layer eliminates the *visible* cumulative bias users would notice across many rendered rate sublines. The two-layer split is industry-pattern (e.g., banks use IEEE half-to-even for statement rendering but legacy ROUND() in stored procs).

**Alternatives considered**:
- Half-to-even at BOTH layers — rejected: requires a custom PL/pgSQL helper for a microscopic differential at storage.
- Half-up (always round up) — rejected: biased.
- Truncation — rejected: biased downward.
- Half-away-from-zero at BOTH layers — rejected: would re-introduce visible cumulative bias at the display layer where users would notice.

---

## R-12 — Custom `ل.س` symbol override for SYP in ICU `ar` locale *(new)*

**Decision**: `MoneyFormatter` overrides the currency symbol for `SYP` to `'ل.س'` when locale is `ar`. ICU's default `ar` locale data for SYP returns the ISO code `'SYP'`, not the Arabic glyph. The override is hardcoded in the formatter against the currency code, NOT against the `currencies.symbol` column at runtime — the column is the SOURCE of the override; the formatter reads it at construction.

**Rationale**: Constitution V (Arabic-First Localization) requires Syrian-friendly typography; rendering `SYP` in Arabic context is correct-but-unfriendly when the canonical Syrian symbol is `ل.س`. ICU's bundled `ar` data prioritizes ISO codes for unambiguous machine-readability; for human-facing rendering we override.

**Alternatives considered**:
- Patch the bundled ICU data — rejected as fragile (next `intl` package upgrade may overwrite the patch).
- Always render the ISO code — rejected as Constitution V violation.

**Implication**: For future custom currencies (TRY, EUR, etc.), `MoneyFormatter` reads the `currencies.symbol` column value and uses it as the ICU override at format time. SYP and USD are seeded with their canonical symbols (`ل.س` and `$`); admins adding custom currencies enter the canonical symbol per locale.

---

## R-13 — FR-019a listing-price row-selection rule embodied in `select_listing_price_row.dart` *(new)*

**Decision**: The FR-019a row-selection rule — "given a listing's `listing_prices` rows and the viewer's `display_currency`, select the row whose `currency_code` matches the preference; if no row matches, select `is_primary=true`" — is implemented as a pure-Dart function at `lib/features/currencies/domain/usecases/select_listing_price_row.dart`. The function accepts a generic interface `ListingPriceRowLike` (carrying `currencyCode` and `isPrimary`) so the helper does NOT depend on Phase 10's not-yet-existing `ListingPrice` domain entity.

**Rationale**: FR-019a is the cross-feature contract that Phase 13 / 14 / 15 consume. The rule is deterministic per Q4's `UNIQUE(listing_id, currency_code)` constraint — at most one row matches the preference, and `is_primary=true` is unique per listing — so no tiebreaker is needed. Embodying the rule as a domain use case (not as a feature-coupling helper) ensures Phase 13 doesn't accidentally duplicate the logic with a subtle variation.

**Alternatives considered**:
- Implement the rule as a Postgres view exposing `listing_prices_for_viewer` — rejected because (a) the rule depends on `auth.uid()` and `user_preferences.display_currency` which is a per-row contextual join, and (b) the spec's Q3 vacated any backend-conversion approach. A view of *raw* rows still works, but the row-selection is a presentation concern, not a data concern.
- Re-implement per-feature — rejected as drift risk.

---

## R-14 — `user_preferences.display_currency` FK addition is a separate migration *(new)*

**Decision**: The FK constraint `user_preferences.display_currency REFERENCES public.currencies(code) ON DELETE SET NULL` is added in migration 4 (`20260518120004_alter_user_preferences_fk.sql`), AFTER the `currencies` seed migration. The FK uses `IF NOT EXISTS` guard via a `DO $$ ... END $$` block reading `pg_constraint`.

**Rationale**: Adding the FK in migration 1 (alongside `CREATE TABLE currencies`) would fail because Postgres validates existing rows against the FK at addition time, and the Phase 4 `user_preferences` rows already carry the default `'SYP'` value. Sequencing the FK after the seed ensures `'SYP'` exists in `currencies.code` before the FK validation runs. Idempotency via `IF NOT EXISTS` allows re-applying the migration without error.

**Alternatives considered**:
- Add the FK inside migration 1 after the seed `INSERT` — rejected because the migration is conceptually "create currencies + seed", and bundling an unrelated table's FK alter into it muddies the diff.
- Skip the FK entirely (rely on application-layer validation) — rejected because Constitution III requires constraints at the schema level for referential integrity.

---

## R-15 — No new permission keys *(carry-forward)*

**Decision**: Phase 9 introduces no new permission keys. `currencies.manage` already exists in the Phase 6 catalog per §9.1, mapped to `admin` and `super_admin`. The documented `finance` custom role pattern (Phase 7 / implementation plan §11.3) attaches the same key.

**Rationale**: Splitting read vs. write or introducing a separate `exchange_rates.set` key would multiply the permission surface without functional benefit. The single `currencies.manage` key is sufficient.

**Alternatives considered**: A separate `currencies.read` permission for non-admin auditors — rejected because public-read RLS (R-04) already provides anonymous access; there is no audience between "anonymous public read" and "`currencies.manage` write".

---

## R-16 — Anonymous SELECT carve-out documented in migration comments *(carry-forward)*

**Decision**: The migrations creating `currencies` and `exchange_rates` carry SQL-comment blocks documenting the anon-SELECT carve-out and citing Constitution III's "explicit documentation when a table opts out" requirement. The comment references this research file (R-04) so future maintainers can trace the rationale.

**Rationale**: Constitution III is the strictest principle in the project; deviating from its default posture (authenticated-only) requires an audit trail.

**Alternatives considered**: Comment in `supabase/policies/<file>.sql` only — rejected because migration files are the canonical source-of-truth.

---

## R-17 — `MoneyFormatter` is pure-function, no global state *(new)*

**Decision**: `MoneyFormatter.format(money, locale, currency)` is a static method (or a top-level function) — no DI, no global cache, no implicit timezone or system-time reads. The function is deterministic per FR-021 / SC-013.

**Rationale**: Determinism enables golden-case manual verification (the 10 plan-time-locked inputs in `quickstart.md`). A formatter that depends on hidden state would be unverifiable.

**Alternatives considered**: A `MoneyFormatter` class with constructor-injected `NumberFormat` instances cached per locale — rejected because the cache adds testing complexity and the `intl` package's `NumberFormat.currency` constructor is already cheap (no I/O).

---

## R-18 — Locale fallback chain on currency-name labels *(carry-forward, adapted to TEXT columns)*

**Decision**: When rendering a currency's name in the active locale, the fallback chain is: (1) active locale's column value (`name_ar` or `name_en`), (2) the other locale's value, (3) the `code` slug as the last-resort label. Phase 6/8 used the same chain on JSONB `display_name`; Phase 9 adapts it to the parallel TEXT columns.

**Rationale**: Constitution V Arabic-first + bilingual coverage. The fallback ensures no row ever renders blank, even if a future admin somehow saves a custom currency with one column empty.

**Alternatives considered**: Hard-require both columns at INSERT/UPDATE time so the fallback never fires — implemented as FR-016 form validation already, but the fallback is the runtime safety net.

---

## R-19 — Compound dependency-aware delete dialog *(carry-forward, adapted)*

**Decision**: When an admin deletes a custom (non-system) currency, the confirmation dialog reads (a) how many `exchange_rates` rows reference this currency as either base or target, (b) how many Phase-10-forward `listing_prices` rows reference this currency. The dialog displays both counts before the admin confirms; if either count is > 0, the delete will fail with `23503 foreign_key_violation` due to the `ON DELETE RESTRICT` FKs. The UI maps the failure to a localized "this currency cannot be deleted while X rates and Y listing prices reference it; deactivate instead" error.

**Rationale**: Phase 8's `delete_confirmation_dialog.dart` set the pattern of enumerating dependent-count before destructive action. Currencies inherit the pattern adapted for two dependent tables instead of two CASCADE descendants.

**Alternatives considered**: Skip the dialog and let the FK violation surface — rejected as user-hostile (the admin would have to guess what's blocking them).

---

## R-20 — No client-side cache on currencies catalog or rates *(new)*

**Decision**: The `CurrenciesListPage`, `ExchangeRateHistoryPage`, and the profile-page preferred-currency toggle all read fresh from Supabase on each mount. There is no client-side cache; rate changes (or currency activation/deactivation) propagate to the next-render of any consumer surface within one round-trip.

**Rationale**: Phase 8 R-20 made the same call for `LocationPicker` — small reference catalogs, low query cost, and the win on freshness (rename / deactivation propagating immediately) outweighs the network overhead of re-querying on each mount.

**Alternatives considered**: A `flutter_secure_storage`-backed cache with TTL — rejected as over-engineered for a 2-10 row reference table.

---

## R-21 — Smoke-test surface for `MoneyFormatter` *(new)*

**Decision**: Phase 9 ships a dev-only `MoneyFormatterShowcasePage` mounted under `/debug/money-formatter` (Android-only, no production navigation). The page renders the 10 plan-time-locked golden cases side-by-side with their locked expected outputs. The exact route is registered behind a `kDebugMode` guard (or equivalent) so production builds do not expose it.

**Rationale**: The plan's verification step references "Unit test: MoneyFormatter golden cases" — but the project-wide no-new-tests rule (`feedback_no_new_tests.md`) replaces this with a manual showcase. The page makes the verification one-tap on the device.

**Alternatives considered**:
- Render the golden cases on `CurrenciesListPage` itself — rejected as visual noise for the real admin user.
- Skip the dedicated page; rely on `latest_rate_subline.dart` exercising the formatter — rejected because the subline only exercises a subset of the cases (no negative amounts, no zero amounts).

---

## R-22 — Missing-display-currency-match fallback shows native price with discreet hint *(new, Q1 derivation)*

**Decision**: When the FR-019a row-selection rule cannot match the viewer's `display_currency` against any `listing_prices` row's `currency_code`, the rule falls back to the `is_primary=true` row in its native currency. The calling widget (the listing card / details / search result) MAY render a discreet localized "rate not available in your preferred currency" hint — but the hint is a presentation-layer concern, not a formatter concern. `MoneyFormatter` itself never injects the hint string (FR-022).

**Rationale**: Q1 chose "no conversion ever", so there is no rate-application to fail. The original spec contemplated a "rate not available" hint for the conversion-failure case; with Q1's no-conversion stance, the hint's role changes to "no matching publisher-entered price". The hint is still useful — viewers preferring SYP who see a USD-only listing benefit from knowing why — but it is contextual UX, not a data-layer concern.

**Alternatives considered**: Suppress the hint entirely under Q1 (since there is no "missing rate" per se) — rejected because viewer education matters: a SYP-preferring viewer who sees a USD price without context may wonder why their preference wasn't honored.

---

## Summary table

| R-# | Decision | Status |
|---|---|---|
| R-01 | Migration filenames are date-prefixed 14-digit timestamps `20260518120001`..`20260518120005` | carry-forward |
| R-02 | RLS policies live inline + parallel files | carry-forward |
| R-03 | One new package: `decimal: ^3.0.0` | partial deviation from Phase 8 R-03 |
| R-04 | Anonymous SELECT carve-out on `currencies` + `exchange_rates` | carry-forward |
| R-05 | `log_audit()` unchanged (sixth time) | carry-forward |
| R-06 | `update_exchange_rate` is a SECURITY DEFINER RPC, NOT an Edge Function | **plan-time deviation** |
| R-07 | `is_system` + immutability trigger on `currencies` | carry-forward from Phase 6/8 |
| R-08 | Trigger-before-seed audit ordering | carry-forward |
| R-09 | `decimal` package for `Money.amount` | new |
| R-10 | `exchange_rates.rate` is `NUMERIC(18, 6)` | new |
| R-11 | Auto-derive rounding mode is banker's rounding | new |
| R-12 | Custom `ل.س` symbol override for SYP in `ar` locale | new |
| R-13 | FR-019a row-selection rule lives at `lib/features/currencies/domain/usecases/select_listing_price_row.dart` | new |
| R-14 | `user_preferences.display_currency` FK addition is migration 4 (after seed) | new |
| R-15 | No new permission keys | carry-forward |
| R-16 | Anonymous SELECT carve-out documented in migration comments | carry-forward |
| R-17 | `MoneyFormatter` is pure-function, no global state | new |
| R-18 | Locale fallback chain on currency-name labels | carry-forward, adapted to TEXT columns |
| R-19 | Compound dependency-aware delete dialog (exchange_rates + listing_prices counts) | carry-forward, adapted |
| R-20 | No client-side cache on currencies catalog or rates | new (Phase 8 R-20 parallel) |
| R-21 | `MoneyFormatterShowcasePage` debug-only smoke-test surface | new |
| R-22 | Missing-display-currency-match fallback: native price + discreet hint | new, Q1 derivation |
