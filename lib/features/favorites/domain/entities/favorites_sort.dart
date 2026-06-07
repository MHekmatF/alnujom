// lib/features/favorites/domain/entities/favorites_sort.dart
//
// Phase 25 uplift v2 — client-side sort order for the FavoritesPage.
//
// The datasource pages `v_favorites` server-side ordered by `favorited_at
// DESC` (keyset pagination). There is no server-side sort parameter for
// favorites yet, so the page re-orders the already-loaded items in memory.
// See the backend follow-up noted in the bloc.

/// How the user's saved listings are ordered on the FavoritesPage.
enum FavoritesSort {
  /// Newest-saved first — matches the server's natural `favorited_at DESC`
  /// order (the default).
  recentlySaved,

  /// Highest primary price first. Items without a price (RLS-hidden /
  /// unavailable rows) sort last.
  priceDesc,

  /// Lowest primary price first. Items without a price sort last.
  priceAsc,
}
