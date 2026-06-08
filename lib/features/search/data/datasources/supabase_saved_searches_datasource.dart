// lib/features/search/data/datasources/supabase_saved_searches_datasource.dart
//
// Phase 25 premium uplift — Supabase I/O for the owner-scoped `saved_searches`
// table (cols: id, user_id, label, filters jsonb, created_at; owner-only RLS).
//
// This file imports supabase_flutter directly. The pre-existing sole importer
// under lib/features/search/ is the search datasource; this is a new, separate
// datasource for the saved-searches feature surface (RLS-scoped writes/reads),
// mirroring how each feature owns its own Supabase datasource.
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/saved_search_dto.dart';

/// Sentinel thrown when an anonymous caller attempts a saved-searches write.
class SavedSearchAuthRequired implements Exception {
  const SavedSearchAuthRequired();
}

@injectable
class SupabaseSavedSearchesDatasource {
  SupabaseSavedSearchesDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Inserts a new saved search for the current user. Returns the created row.
  /// Throws [SavedSearchAuthRequired] when no user is signed in.
  Future<SavedSearchDto> create({
    required String label,
    required Map<String, dynamic> filters,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const SavedSearchAuthRequired();

    final row = await _client
        .from('saved_searches')
        .insert({'user_id': uid, 'label': label, 'filters': filters})
        .select()
        .single();

    return SavedSearchDto.fromJson(Map<String, dynamic>.from(row));
  }

  /// Lists the current user's saved searches, newest-first. Empty when
  /// anonymous (owner-only RLS would return nothing anyway).
  Future<List<SavedSearchDto>> list() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const <SavedSearchDto>[];

    final rows = await _client
        .from('saved_searches')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((r) => SavedSearchDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Deletes a saved search by id (owner-only RLS gates this server-side).
  Future<void> delete(String id) async {
    await _client.from('saved_searches').delete().eq('id', id);
  }
}
