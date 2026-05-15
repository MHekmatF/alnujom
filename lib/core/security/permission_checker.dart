import 'package:injectable/injectable.dart';

import 'permission_catalog_repository.dart';

/// Session-scoped singleton that caches the current user's effective permission set.
/// On refresh failure, the previous cache is retained (fail-open-to-last-known-state).
/// Constitution IX: no Supabase import — consumes the abstract repository only.
@lazySingleton
class PermissionChecker {
  final PermissionCatalogRepository _repo;
  Set<String> _cache = const <String>{};
  bool _loaded = false;

  PermissionChecker(this._repo);

  /// Populates the cache from the repository. Called at sign-in.
  Future<void> load() async {
    try {
      _cache = await _repo.loadEffectivePermissions();
      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  /// Re-fetches and replaces the cache atomically.
  /// On failure, retains the previous cache so callers see stale-but-valid data.
  Future<void> refresh() async {
    try {
      final fresh = await _repo.loadEffectivePermissions();
      _cache = fresh;
      _loaded = true;
    } catch (_) {
      // retain previous _cache
    }
  }

  /// Returns true if the cache contains [permKey].
  bool has(String permKey) => _cache.contains(permKey);

  /// Returns true if the cache contains any key in [permKeys].
  bool any(Iterable<String> permKeys) => permKeys.any(_cache.contains);

  /// Returns true if the cache contains every key in [permKeys].
  bool all(Iterable<String> permKeys) => permKeys.every(_cache.contains);

  /// Clears the cache and resets loaded state. Called at sign-out.
  void clear() {
    _cache = const <String>{};
    _loaded = false;
  }

  bool get isLoaded => _loaded;
}
