import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/permission_catalog_entry.dart';
import '../../domain/entities/role_detail.dart';
import '../../domain/entities/role_mutation_result.dart';
import '../../domain/entities/role_with_counts.dart';
import '../../domain/failures.dart';
import '../../domain/repositories/role_catalog_repository.dart';
import '../datasources/supabase_role_catalog_datasource.dart';

@LazySingleton(as: RoleCatalogRepository)
class RoleCatalogRepositoryImpl implements RoleCatalogRepository {
  RoleCatalogRepositoryImpl(this._ds, this._logger);

  static const _tag = 'RoleCatalogRepositoryImpl';

  final SupabaseRoleCatalogDataSource _ds;
  final AppLogger _logger;

  @override
  Future<List<RoleWithCounts>> listRoles() async {
    try {
      final roles = await _ds.listRoles();
      return roles.map((role) => role.toEntity()).toList();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<RoleDetail> loadRoleDetail(String roleId) async {
    try {
      return (await _ds.loadRoleDetail(roleId)).toEntity();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<List<PermissionCatalogEntry>> loadPermissionCatalog() async {
    try {
      final permissions = await _ds.loadPermissionCatalog();
      return permissions.map((permission) => permission.toEntity()).toList();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<RoleMutationResult> createRole({
    required String roleKey,
    required Map<String, String> displayName,
    required String? description,
    required List<String> permissionKeys,
  }) async {
    try {
      final result = await _ds.mutateRole({
        'op': 'create',
        'role_id': null,
        'role_key': roleKey,
        'display_name': displayName,
        'description': description,
        'permission_keys': permissionKeys,
        'expected_updated_at': null,
      });
      return result.toEntity();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestException(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<RoleMutationResult> updateRole({
    required String roleId,
    required Map<String, String> displayName,
    required String? description,
    required List<String> permissionKeys,
    required DateTime expectedUpdatedAt,
  }) async {
    try {
      final result = await _ds.mutateRole({
        'op': 'update',
        'role_id': roleId,
        'role_key': null,
        'display_name': displayName,
        'description': description,
        'permission_keys': permissionKeys,
        'expected_updated_at': expectedUpdatedAt.toIso8601String(),
      });
      return result.toEntity();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestException(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> deleteRole({
    required String roleId,
    required DateTime expectedUpdatedAt,
  }) async {
    try {
      await _ds.mutateRole({
        'op': 'delete',
        'role_id': roleId,
        'role_key': null,
        'display_name': null,
        'description': null,
        'permission_keys': null,
        'expected_updated_at': expectedUpdatedAt.toIso8601String(),
      });
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestException(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<int> loadAffectedUserCount(String roleId) async {
    try {
      return await _ds.loadAffectedUserCount(roleId);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestException(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<List<String>> loadUserIdsForRole(String roleId) async {
    try {
      return await _ds.loadUserIdsForRole(roleId);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestException(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  SuperAdminFailure _mapPostgrestException(
    PostgrestException error,
    StackTrace stackTrace,
  ) {
    _logger.warning(
      'Super-admin role mutation data error.',
      error: error,
      stackTrace: stackTrace,
      tag: _tag,
    );
    final code = error.code ?? '';
    final msg = error.message;
    // 20260516120003_create_mutate_role_rpc.sql: RAISE EXCEPTION 'role concurrent edit'.
    if (code == '40001') return const RoleEditConflictFailure();
    // 20260516120003_create_mutate_role_rpc.sql: 'super_admin permission set is immutable'.
    if (code == '42501' && msg.contains('super_admin permission set')) {
      return const SuperAdminPermissionsImmutableFailure();
    }
    // Phase 6 system role trigger messages include cannot delete/rename system role.
    if (code == '42501' &&
        (msg.contains('system role') ||
            msg.contains('cannot delete') ||
            msg.contains('cannot rename'))) {
      return const SystemRoleImmutableFailure();
    }
    if (code == '42501') return const RolePermissionDeniedFailure();
    if (code == '23503') return const RoleHasUsersFailure();
    if (code == '23505') return const RoleKeyDuplicateFailure();
    if (code == '22023') return const InvalidOpFailure();
    return BackendFailure(msg, cause: error, stackTrace: stackTrace);
  }

  BackendFailure _mapError(Object error, StackTrace stackTrace) {
    _logger.warning(
      'Super-admin role catalog data error.',
      error: error,
      stackTrace: stackTrace,
      tag: _tag,
    );
    return BackendFailure(
      error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
