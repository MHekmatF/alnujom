// Phase 21 (spec/021-ads-banners) — AdPlacement enum.
//
// The five ad placements defined in the `placement_key` CHECK constraints
// on `public.ad_placements` and `public.ad_impressions` (data-model §2 / §3).
//
// Wire-key mapping is provided via [wireValue]; the reverse via [fromWire].
//
// Note: [categoryBanner] is defined in the schema but NOT host-wired in
// Phase 21 (R-175 / FR-014). The admin placement picker should signal it
// as "not yet live".
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

/// Banner placement positions, matching the DB `placement_key` CHECK values.
enum AdPlacement {
  homeTopBanner('home_top_banner'),
  homeMiddleBanner('home_middle_banner'),
  searchResultsBanner('search_results_banner'),
  listingDetailsBanner('listing_details_banner'),

  /// Defined in the schema but NOT host-wired this phase (R-175 / FR-014).
  categoryBanner('category_banner');

  const AdPlacement(this.wireValue);

  /// The DB / wire string value for this placement.
  final String wireValue;

  /// Parse from a wire string; throws [StateError] for unknown values.
  static AdPlacement fromWire(String v) =>
      AdPlacement.values.firstWhere(
        (e) => e.wireValue == v,
        orElse: () => throw StateError('Unknown AdPlacement wire value: $v'),
      );
}
