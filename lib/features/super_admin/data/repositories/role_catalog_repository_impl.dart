import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/permission_catalog_entry.dart';
import '../../domain/entities/role_detail.dart';
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
