// lib/features/recently_viewed/data/local/recently_viewed_store.dart
//
// Local-only persistence of the listings the user has most recently opened,
// backing the Home "recently viewed" row. Stored as a JSON array string in
// flutter_secure_storage (the app's single local-prefs mechanism — there is no
// shared_preferences dependency). Most-recent-first, de-duplicated by listing
// id and capped at [_maxEntries]. Failures are swallowed (read → empty, write →
// no-op) so a storage hiccup never blocks viewing a listing.
//
// As a data-layer datasource it is the Constitution-IX-clean home for the
// `supabase_flutter` storage-URL resolution: the listing-details page hands us
// the raw main-image storage PATH, and we resolve it to a public URL here
// before persisting, so the presentation layer never touches Supabase.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/recently_viewed_listing.dart';

@LazySingleton()
class RecentlyViewedStore {
  RecentlyViewedStore(this._logger) : _storage = const FlutterSecureStorage();

  static const _tag = 'RecentlyViewedStore';
  static const _key = 'com.alnujom.recently_viewed.listings_v1';
  static const _maxEntries = 10;
  static const _bucket = 'listing-images';

  final AppLogger _logger;
  final FlutterSecureStorage _storage;

  /// Returns the recently-viewed listings, most-recent-first. Empty on any
  /// failure or when nothing has been viewed.
  Future<List<RecentlyViewedListing>> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return const <RecentlyViewedListing>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <RecentlyViewedListing>[];
      return decoded
          .map(RecentlyViewedListing.fromJson)
          .whereType<RecentlyViewedListing>()
          .take(_maxEntries)
          .toList(growable: false);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to read recently-viewed listings (treating as empty).',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return const <RecentlyViewedListing>[];
    }
  }

  /// Prepends [item] as the newest entry, removing any prior entry with the same
  /// id, and caps the list at [_maxEntries]. Returns the resulting list so the
  /// caller can update state without an extra read. No-op (returns the current
  /// list) on a blank id or any write failure.
  Future<List<RecentlyViewedListing>> record(
    RecentlyViewedListing item,
  ) async {
    if (item.id.isEmpty) return read();
    try {
      final current = await read();
      final next = <RecentlyViewedListing>[
        item,
        ...current.where((e) => e.id != item.id),
      ].take(_maxEntries).toList(growable: false);
      await _storage.write(
        key: _key,
        value: jsonEncode(next.map((e) => e.toJson()).toList(growable: false)),
      );
      return next;
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to persist recently-viewed listing.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return read();
    }
  }

  /// Clears all stored recently-viewed listings.
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to clear recently-viewed listings.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  /// Resolves the public URL for a `listing-images` storage [path], mirroring
  /// the resolution [ListingGallery] performs. Returns null for a null/empty
  /// path or on any failure, so the card falls back to its image placeholder.
  ///
  /// Lives here (a `data/` datasource) so the presentation layer that records a
  /// viewed listing never imports `package:supabase_flutter` (Constitution IX).
  String? resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      return Supabase.instance.client.storage.from(_bucket).getPublicUrl(path);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to resolve recently-viewed image URL.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return null;
    }
  }
}
