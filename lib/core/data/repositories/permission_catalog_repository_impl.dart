import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../security/permission_catalog_repository.dart';

/// Supabase implementation of [PermissionCatalogRepository].
///
/// Kept outside `core/security` so security-domain files remain Supabase-free.
@LazySingleton(as: PermissionCatalogRepository)
class PermissionCatalogRepositoryImpl implements PermissionCatalogRepository {
  PermissionCatalogRepositoryImpl();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  @override
  Future<Set<String>> loadEffectivePermissions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const <String>{};

    try {
      final raw = await _client
          .from('user_roles')
          .select('role:roles(role_permissions(permission:permissions(key)))')
          .eq('user_id', userId);

      // Response shape (one element per user_roles row for this user):
      // [{ 'role': { 'role_permissions': [{ 'permission': { 'key': 'users.approve' } }] } }]
      final keys = <String>{};
      for (final row in (raw as List)) {
        final rolePermissions =
            ((row as Map)['role'] as Map?)?['role_permissions'] as List? ??
            const [];
        for (final rp in rolePermissions) {
          final key = ((rp as Map)['permission'] as Map?)?['key'] as String?;
          if (key != null) keys.add(key);
        }
      }
      return keys;
    } on supabase.PostgrestException catch (e) {
      throw NetworkErrorPermission(e.message);
    } catch (e) {
      throw UnknownPermissionError(e);
    }
  }
}
