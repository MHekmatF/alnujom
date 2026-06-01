// Phase 21 (spec/021-ads-banners) — AdLinkKind enum.
//
// Discriminator for the ad tap-through target (R-169 / R-179).
// Maps to the `link_kind` TEXT CHECK column in the `ads` table.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

/// The kind of destination an ad links to on tap.
///
/// Wire values match the `link_kind` CHECK constraint in `public.ads`:
///   external → absolute web URL (opens in browser)
///   listing  → listing UUID (→ /listings/:id)
///   agency   → agency UUID  (→ /agency/:id)
///   category → property-type key (→ filtered search)
///   search   → free-text query string (→ /search pre-filled)
enum AdLinkKind {
  external('external'),
  listing('listing'),
  agency('agency'),
  category('category'),
  search('search');

  const AdLinkKind(this.wireValue);

  /// The string value used as `link_kind` on the wire and in the DB CHECK.
  final String wireValue;

  /// Parse from a wire string; throws [StateError] for unknown values.
  static AdLinkKind fromWire(String v) => AdLinkKind.values.firstWhere(
    (e) => e.wireValue == v,
    orElse: () => throw StateError('Unknown AdLinkKind wire value: $v'),
  );
}
