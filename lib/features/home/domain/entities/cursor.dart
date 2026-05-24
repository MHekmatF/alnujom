import 'package:equatable/equatable.dart';

import 'home_listing_card.dart';

/// Phase 13 — opaque cursor for the home-feed pagination per data-model.md
/// §2.4 + research.md R-62 (corrected).
///
/// The cursor lives ONLY in `HomeBloc` state — it is not persisted across app
/// launches and is never exposed in any URL.
///
/// Marshaled to a PostgREST `.or()` filter expressing the lexicographic
/// strict-less-than tuple compare on `(published_at, id)`. See
/// `SupabaseHomeFeedDatasource.fetchPage` for the wire format.
class Cursor extends Equatable {
  const Cursor({required this.publishedAt, required this.id});

  /// Convenience constructor — derives the cursor from the last card in the
  /// currently-loaded page. The next page query asks PostgREST for rows
  /// strictly less than `(publishedAt, id)` in lexicographic order.
  Cursor.fromLastCard(HomeListingCard last)
      : publishedAt = last.publishedAt,
        id = last.id;

  final DateTime publishedAt;
  final String id;

  @override
  List<Object?> get props => [publishedAt, id];
}
