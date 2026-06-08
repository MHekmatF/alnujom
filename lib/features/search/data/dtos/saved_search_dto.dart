// lib/features/search/data/dtos/saved_search_dto.dart
//
// Phase 25 premium uplift — maps one row of the owner-scoped `saved_searches`
// table (cols: id, user_id, label, filters jsonb, created_at) onto the domain
// [SavedSearch]. The `filters` JSONB payload is round-tripped through
// [FilterState.toJson] / [FilterState.fromJson].
import '../../domain/entities/filter_state.dart';
import '../../domain/entities/saved_search.dart';

class SavedSearchDto {
  const SavedSearchDto({
    required this.id,
    required this.label,
    required this.filters,
    required this.createdAt,
  });

  final String id;
  final String label;
  final Map<String, dynamic> filters;
  final String createdAt;

  factory SavedSearchDto.fromJson(Map<String, dynamic> json) {
    final rawFilters = json['filters'];
    return SavedSearchDto(
      id: json['id'].toString(),
      label: (json['label'] as String?) ?? '',
      filters: rawFilters is Map
          ? Map<String, dynamic>.from(rawFilters)
          : const <String, dynamic>{},
      createdAt: json['created_at'].toString(),
    );
  }

  SavedSearch toEntity() => SavedSearch(
    id: id,
    label: label,
    filters: FilterState.fromJson(filters),
    createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
  );
}
