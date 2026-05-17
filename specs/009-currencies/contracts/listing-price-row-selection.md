# Contract: Listing-Price Row-Selection Rule (FR-019a)

**Owner**: Phase 9 (`lib/features/currencies/domain/usecases/select_listing_price_row.dart`).
**Consumers**: Phase 13 listing details + home grid, Phase 14 search results, Phase 15 map popovers, Phase 16 inquiry forms — every surface that renders a listing's price.
**Stability**: API is stable for v1. The rule embodies Q1's no-conversion stance + Q4's uniqueness contract.

## Public API

```dart
/// Picks which row from a listing's [listing_prices] to display to the viewer.
///
/// Per FR-019a / Q1 / Q4, the rule is fully deterministic:
///   1. Look for a row whose [currencyCode] matches [viewerPreferredCurrencyCode].
///   2. If no row matches, return the row where [isPrimary] is true.
///
/// Phase 10's `UNIQUE(listing_id, currency_code)` constraint guarantees at most
/// one row matches step 1. The listing schema's "exactly one is_primary=true per
/// listing" invariant guarantees step 2 returns a single row.
///
/// Returns null only if [rows] is empty (e.g., a draft listing pre-pricing).
ListingPriceRowLike? selectListingPriceRow(
  Iterable<ListingPriceRowLike> rows, {
  required String? viewerPreferredCurrencyCode,
});

/// The minimum shape this rule needs. Phase 10's [ListingPrice] entity implements
/// this interface; this contract is currency-feature-facing, so it does NOT
/// import Phase 10.
abstract class ListingPriceRowLike {
  String get currencyCode;
  bool get isPrimary;
}
```

## Obligations

1. **Deterministic single-match**: Given a non-empty `rows` iterable and Phase 10's `UNIQUE(listing_id, currency_code)` constraint (Q4), step 1 returns at most one row.
2. **Always returns a row when `rows` is non-empty**: At least one row has `isPrimary=true` per Phase 10's schema invariant; step 2 will always succeed when step 1 misses.
3. **No I/O, no async**: The function is synchronous and pure. It does NOT query the database; the caller fetches the rows first.
4. **No exchange-rate lookup or multiplication**: Per Q1 / SC-023. The function picks a row; it does not transform any amount.
5. **Returns `null` if and only if `rows` is empty**: The caller (e.g., a listing card widget) is responsible for handling the "price on request" treatment per US5 acceptance scenario 6.
6. **Anonymous-viewer support**: When `viewerPreferredCurrencyCode == null` (e.g., anonymous user with no `user_preferences` row), step 1 is skipped entirely and the function returns the `isPrimary=true` row.

## Verification

```dart
// Manual check on a smoke-test screen OR direct dart REPL:

// Case 1: USD-only listing, viewer prefers SYP → returns USD primary row (fallback)
final rows = [TestRow(currencyCode: 'USD', isPrimary: true)];
final result = selectListingPriceRow(rows, viewerPreferredCurrencyCode: 'SYP');
// Expected: result.currencyCode == 'USD'

// Case 2: USD + SYP listing, viewer prefers SYP → returns SYP row
final rows2 = [
  TestRow(currencyCode: 'USD', isPrimary: true),
  TestRow(currencyCode: 'SYP', isPrimary: false),
];
final result2 = selectListingPriceRow(rows2, viewerPreferredCurrencyCode: 'SYP');
// Expected: result2.currencyCode == 'SYP'

// Case 3: Empty listing → null
final result3 = selectListingPriceRow([], viewerPreferredCurrencyCode: 'SYP');
// Expected: result3 == null

// Case 4: Anonymous viewer → returns primary
final result4 = selectListingPriceRow(rows2, viewerPreferredCurrencyCode: null);
// Expected: result4.currencyCode == 'USD' (the primary)
```

## Forbidden

- Adding an `exchangeRate` parameter (Q1 / SC-023).
- Adding a `Locale` parameter — the rule picks a row; formatting (with locale) happens later in `MoneyFormatter`.
- Querying the database from inside the function — pure-Dart, sync, no I/O.
- Picking a row by `created_at` or any field other than the rule defines. The rule is deterministic by `currencyCode` match → `isPrimary` fallback only.
