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
