import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/permission_dto.dart';
import '../dtos/role_detail_dto.dart';
import '../dtos/role_with_counts_dto.dart';

@LazySingleton()
class SupabaseRoleCatalogDataSource {
  SupabaseRoleCatalogDataSource();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  Future<List<RoleWithCountsDto>> listRoles() async {
    final response = await _client
        .from('roles')
        .select(
          'id, key, display_name, description, is_system, created_at, updated_at, role_permissions(count), user_roles(count)',
        )
        .order('key');

    return response.map((row) => RoleWithCountsDto.fromJson(row)).toList();
  }

  Future<RoleDetailDto> loadRoleDetail(String roleId) async {
    final response = await _client
        .from('roles')
        .select(
          'id, key, display_name, description, is_system, created_at, updated_at, role_permissions(permission:permissions(key))',
        )
        .eq('id', roleId)
        .single();

    return RoleDetailDto.fromJson(response);
  }

  Future<List<PermissionDto>> loadPermissionCatalog() async {
    final response = await _client
        .from('permissions')
        .select('id, key, category, description')
        .order('category')
        .order('key');

    return response.map((row) => PermissionDto.fromJson(row)).toList();
  }
}
