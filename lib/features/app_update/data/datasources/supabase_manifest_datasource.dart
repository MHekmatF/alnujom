import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/version_manifest_dto.dart';

/// Fetches the version manifest JSON from Supabase Storage.
///
/// The manifest is a public-read object uploaded by the operator (R-209).
/// This datasource is the SOLE importer of `supabase_flutter` for the
/// `app_update` feature — `domain/` has zero platform-SDK imports (Principle IX).
///
/// [bucket] and [path] are configurable so the operator can reorganise the
/// Storage layout without changing Dart code (defaulted to the spec values).
@injectable
class SupabaseManifestDatasource {
  SupabaseManifestDatasource(
    this._client, {
    String bucket = 'app-release',
    String path = 'android/latest.json',
  })  : _bucket = bucket,
        _path = path;

  final supabase.SupabaseClient _client;
  final String _bucket;
  final String _path;

  /// Download and decode the version manifest.
  ///
  /// Returns a [VersionManifestDto] on success, or throws on any network /
  /// storage error.  The caller (repository) wraps all throws in [CheckFailed].
  Future<VersionManifestDto?> fetchManifest() async {
    final bytes = await _client.storage.from(_bucket).download(_path);
    final jsonString = utf8.decode(bytes);
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) return null;
    return VersionManifestDto.fromJson(decoded);
  }
}
