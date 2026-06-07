// lib/features/search/data/datasources/recent_searches_storage.dart
//
// Phase 25 premium uplift — local-only persistence of the user's last few
// free-text search queries. Stored as a JSON string array in
// flutter_secure_storage (the app's single local-prefs mechanism — there is no
// shared_preferences dependency). Newest-first, de-duplicated case-insensitively
// and capped at [_maxEntries]. Failures are swallowed (read → empty, write →
// no-op) so a storage hiccup never blocks search.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/logging/app_logger.dart';

@LazySingleton()
class RecentSearchesStorage {
  RecentSearchesStorage(this._logger) : _storage = const FlutterSecureStorage();

  static const _tag = 'RecentSearchesStorage';
  static const _key = 'com.alnujom.search.recent_queries_v1';
  static const _maxEntries = 8;

  final AppLogger _logger;
  final FlutterSecureStorage _storage;

  /// Returns the recent queries, newest-first. Empty on any failure.
  Future<List<String>> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return const <String>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded
          .whereType<String>()
          .where((q) => q.trim().isNotEmpty)
          .take(_maxEntries)
          .toList(growable: false);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to read recent searches (treating as empty).',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return const <String>[];
    }
  }

  /// Prepends [query] (trimmed) as the newest entry, removing any prior
  /// case-insensitive duplicate, and caps the list at [_maxEntries]. No-op for
  /// blank queries. Returns the resulting list so callers can update state
  /// without an extra read.
  Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return read();
    try {
      final current = await read();
      final next = <String>[
        trimmed,
        ...current.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
      ].take(_maxEntries).toList(growable: false);
      await _storage.write(key: _key, value: jsonEncode(next));
      return next;
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to persist recent search.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return read();
    }
  }

  /// Clears all stored recent searches.
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to clear recent searches.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }
}
