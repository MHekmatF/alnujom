// lib/features/search/domain/entities/saved_search.dart
//
// Phase 25 premium uplift — a row of the owner-scoped `saved_searches` table.
// `filters` is the structured [FilterState] reconstructed from the stored JSONB
// payload; re-applying a saved search hands these filters back to the
// SearchBloc.
import 'package:equatable/equatable.dart';

import 'filter_state.dart';

class SavedSearch extends Equatable {
  const SavedSearch({
    required this.id,
    required this.label,
    required this.filters,
    required this.createdAt,
  });

  final String id;
  final String label;
  final FilterState filters;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, label, filters, createdAt];
}
