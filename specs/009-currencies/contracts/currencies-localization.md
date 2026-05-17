# Contract: Currencies Localization

**Owner**: Phase 9 (`lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb` updates).
**Consumers**: every new widget under `lib/features/currencies/presentation/` + the profile-page toggle.

## Obligations

Phase 9 adds approximately **25 new ARB keys** per locale (~50 keys total). Each key MUST ship to **both** `app_ar.arb` and `app_en.arb` in the same commit per Phase 3's localization gate.

### Key inventory

See [data-model.md § ARB key inventory](../data-model.md) for the table of categories and example keys. Categories:

| Category | Count | Examples |
|---|---|---|
| Admin page titles | 4 | `currenciesPageTitle`, `setExchangeRatePageTitle`, `exchangeRateHistoryPageTitle`, `currencyFormPageTitle` |
| Tile labels | 1 | `adminHomeCurrenciesTile` |
| Button labels | 5 | `addCurrencyButton`, `setNewRateButton`, `viewHistoryButton`, `deactivateButton`, `confirmButton` |
| Form field labels | 6+ | `currencyCodeLabel`, `currencyNameArLabel`, `currencyNameEnLabel`, `currencySymbolLabel`, `currencySortOrderLabel`, `currencyDisplayDecimalsLabel`, `rateAmountLabel`, `effectiveAtLabel`, `sourceLabel`, `preferredCurrencyLabel` |
| Validation messages | 4 | `currencyCodeFormatError`, `rateMustBePositiveError`, `baseEqualsTargetError`, `displayDecimalsRangeError` |
| Dialog copy | 3 | `deleteCurrencyConfirmTitle`, `unusualTimingFutureTitle`, `unusualTimingBackdateTitle` |
| Structured-error strings | 3 | `errorSystemCurrencyImmutable`, `errorCurrencyHasReferences`, `errorPermissionDenied` |
| Misc UI | 3 | `derivedBadgeLabel`, `rateNotAvailableHint`, `latestRateLineTemplate` (parameterized) |

### Arabic copy quality

Per Constitution V, Arabic copy MUST be Syrian-friendly. Examples:

- `setNewRateButton` (`ar`): `'تعيين سعر جديد'` (NOT `'تحديد سعر صرف جديد'` which is too formal).
- `derivedBadgeLabel` (`ar`): `'مشتق'` or `'محسوب آليًا'` (clear, short).
- `preferredCurrencyLabel` (`ar`): `'العملة المفضلة'`.
- `rateNotAvailableHint` (`ar`): `'السعر بعملتك المفضلة غير متوفر'`.

### Data labels

The bilingual currency names (`name_ar` / `name_en`) come from `public.currencies` columns, NOT from ARB. The R-18 fallback chain (active → other → `code`) governs runtime rendering.

The `symbol` column is locale-independent at the data layer; `MoneyFormatter` applies the locale-driven symbol-position rule (R-12 / Assumption 7) at format time.

### Parameterized keys

`latestRateLineTemplate` is parameterized for "1 {base} = {amount} {target}":

```json
// app_en.arb
"latestRateLineTemplate": "1 {base} = {amount} {target}",
"@latestRateLineTemplate": {
  "description": "Compact admin-awareness rate line on CurrenciesListPage",
  "placeholders": {
    "base": {"type": "String"},
    "amount": {"type": "String"},
    "target": {"type": "String"}
  }
}
```

```json
// app_ar.arb
"latestRateLineTemplate": "1 {base} = {amount} {target}",
// Same placeholders; Arabic RTL is handled by Flutter's bidi resolver at render time
```

## Verification

```bash
# All ~25 keys present in both files
diff <(jq 'keys[] | select(startswith("@") | not)' lib/l10n/app_ar.arb | sort) \
     <(jq 'keys[] | select(startswith("@") | not)' lib/l10n/app_en.arb | sort)
# Expected: no diff (both files have the same key set)

# No hardcoded user-facing strings in the new feature folder
# (Phase 3 lint guard runs at PR time)
```

## Forbidden

- Adding a user-visible string to only one locale file (Phase 3 localization gate blocks merge).
- Hardcoding a string in a widget (Constitution V — lint guard catches it).
- Reusing an existing ARB key for a semantically different message (each key is single-purpose).
- Translating currency names (`name_ar` / `name_en`) — those live in the database, not in ARB.
