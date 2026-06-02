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
/// The bucket/path are fixed `static const`s, NOT constructor params: `@injectable`
/// does not honor primitive constructor defaults — it would emit `gh<String>()`
/// for each, and since no `String` is registered in the DI container that throws
/// at resolution time and bricks cold start (resolving `AppUpdateCubit` in
/// `app.dart` initState, outside the repository's fail-silent guard). The
/// operator reorganises the Storage layout by changing the uploaded object's
/// location convention, not the Dart-side path.
@injectable
class SupabaseManifestDatasource {
  SupabaseManifestDatasource(this._client);

  static const String _bucket = 'app-release';
  static const String _path = 'android/latest.json';

  final supabase.SupabaseClient _client;

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
