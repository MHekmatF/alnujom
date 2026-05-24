// lib/features/search/domain/entities/search_cursor.dart
// SearchCursor sealed class for cursor-based pagination.
// Phase 14 data-model.md §2.5 — declared here in the domain layer so that
// both SearchRepository (domain) and SearchBloc (presentation) can import it
// from a single canonical location. The data-model.md §2.5 note that it lives
// in search_state.dart applies to later phases that have no domain consumer;
// Phase 14 T011 references SearchCursor in the abstract repository signature,
// so the domain layer is the correct home.

sealed class SearchCursor {}

class NewestCursor extends SearchCursor {
  final DateTime publishedAt;
  final String id;
  NewestCursor({required this.publishedAt, required this.id});
}

class PriceCursor extends SearchCursor {
  final double priceAmount;
  final String id;
  PriceCursor({required this.priceAmount, required this.id});
}
