# Contract: Currencies Admin Pages

**Owner**: Phase 9 (`lib/features/currencies/presentation/pages/*`).
**Consumers**: `currencies.manage` permission holders. Hidden / blocked for all other users.

## Pages

| Page | Route | Purpose |
|---|---|---|
| `CurrenciesListPage` | `/admin/currencies` | Catalog index with latest-rate-per-pair sublines (admin awareness only) |
| `CurrencyFormPage` | `/admin/currencies/form?mode=create` / `?mode=edit&code=USD` | Add or edit a currency row |
| `SetExchangeRatePage` | `/admin/currencies/set-rate` | Form that submits to `update_exchange_rate` RPC |
| `ExchangeRateHistoryPage` | `/admin/currencies/:code/history` | Paginated history for a given base currency |

## `CurrenciesListPage`

**State source**: `CurrenciesListBloc` — emits `Loaded(List<CurrencyWithLatestRates>)`. `CurrencyWithLatestRates` carries the currency row + a `Map<targetCode, Decimal>` of the latest rates for each outbound pair (joined at the data layer).

**Layout** (top to bottom):
1. App-bar with the localized "Currencies" title and a "Set new rate" CTA.
2. Per-currency `currency_card.dart` showing:
   - The currency `code` and the active-locale `localizedName` per R-18.
   - The `symbol`.
   - A `system_currency_badge.dart` if `isSystem=true`.
   - A "Hidden" badge if `isActive=false`.
   - A `latest_rate_subline.dart` per outbound pair, e.g., "1 USD = 15,000 SYP". When no rate exists for a pair, the subline shows a localized empty-state placeholder (deferred to plan — see `checklists/requirements.md` Note "Empty state on rate sublines").
   - Per-row affordances: "Edit" (always — even on `isSystem=true` rows, but the form refuses to change `code`), "View history" (navigates to history page), and "Delete" (HIDDEN on `isSystem=true` rows per FR-015a).

**Tile-hide for non-permission-holders**: The page is guarded by the route redirect (FR-014); if a non-permission-holder somehow reaches the page, the route guard refuses and the page never renders.

## `CurrencyFormPage`

**State source**: `CurrencyFormBloc` — emits `Idle / Validating / Saving / SaveSuccess(Currency) / SaveFailure(reason)`.

**Form fields**:
- `code` — required, REGEX `^[A-Z]{3}$`, **disabled when editing a `isSystem=true` row** (FR-015a).
- `name_ar` — required, non-empty.
- `name_en` — required, non-empty.
- `symbol` — required, non-empty.
- `sort_order` — integer ≥ 0, defaults to 100 on create.
- `display_decimals` — integer 0..8, defaults to 2 on create.
- `is_active` — boolean toggle.

**Validation messages**: localized via the `currencyCodeFormatError`, `requiredField`, `displayDecimalsRangeError` ARB keys.

**Save flow**: dispatches `create_currency` or `update_currency` use case; on `SaveFailure`, the page maps SQLSTATE to localized errors:
- `42501` → `errorSystemCurrencyImmutable` ("system currency cannot be renamed or deleted").
- `23505` → `errorDuplicateCode` ("a currency with this code already exists").
- `23514` → form-field-level error per the failing CHECK constraint.

## `SetExchangeRatePage`

**State source**: `SetExchangeRateBloc` — emits `Idle / DerivedRatePreview(Decimal preview) / Saving / SaveSuccess(UpdateExchangeRateResult) / SaveFailure(reason) / UnusualTimingPending(action)`.

**Form fields**:
- `base_currency` — dropdown of `is_active=true` currencies, required.
- `target_currency` — dropdown of `is_active=true` currencies, required, must differ from base.
- `rate` — positive `Decimal`, up to NUMERIC(18,6) precision; the page renders a live "derived inverse preview" line as the admin types (FR-016 transparency — `1 / rate` rounded to 6 decimals).
- `effective_at` — date+time picker, defaults to `now()`. May be past or future.
- `source` — optional text input, ≤ 500 chars.

**Submit flow**:
1. Client-side validation passes.
2. If `effective_at > now() + 24h` OR `effective_at < now() - 24h` (Q5 symmetric gate), the BLoC emits `UnusualTimingPending` and the page shows `unusual_timing_confirmation_dialog.dart` with the timing-direction-appropriate copy (`unusualTimingFutureTitle` / `unusualTimingBackdateTitle`). Admin must confirm before the RPC fires.
3. The page calls `set_exchange_rate` use case → `CurrenciesRepository.setExchangeRate` → `supabase.rpc('update_exchange_rate', ...)`.
4. On `SaveSuccess`, page navigates back to `CurrenciesListPage` with the new rate visible on both directions.

**Error mapping**: SQLSTATE `42501` / `22023` / `23503` / `23514` → localized errors per FR-024.

## `ExchangeRateHistoryPage`

**State source**: `ExchangeRateHistoryBloc` — emits `Initial / Loading / Loaded(List<ExchangeRate>, hasMore) / LoadingMore / Error`.

**Layout**:
1. App-bar with the localized "Exchange rate history for {code}" title (parameterized) and a "Set new rate" CTA pre-filled with the page's base currency.
2. Filter chip: "Target currency = (any | specific code)".
3. Per-row `exchange_rate_row.dart` showing:
   - `target_currency`.
   - `rate` formatted via `MoneyFormatter` (or a simpler digit-grouping formatter for pure numbers, decided at implementation).
   - `effective_at` localized via the active-locale date/time format.
   - `set_by` resolved to the admin's display name (joined against `public.profiles` at the data layer).
   - `source` (or `—` if NULL).
   - `derived_badge.dart` if `exchangeRate.isDerived`.
4. Cursor-paginated scroll loading 50 rows at a time.

## Forbidden

- Showing a Delete affordance for `isSystem=true` currency rows (FR-015a / SC-017).
- Showing an Edit affordance for individual `exchange_rates` history rows — they are immutable (US6 acceptance scenario 5).
- Allowing the `code` field to be edited when `mode=edit` AND the row is `is_system=true`.
- Bypassing the `unusual_timing_confirmation_dialog.dart` for out-of-range `effective_at` values (FR-017 / Q5 / SC-025).
