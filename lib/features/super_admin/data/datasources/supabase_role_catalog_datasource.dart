import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/permission_dto.dart';
import '../dtos/role_detail_dto.dart';
import '../dtos/role_mutation_response_dto.dart';
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

  Future<RoleMutationResponseDto> mutateRole(
    Map<String, dynamic> params,
  ) async {
    final response = await _client.rpc('mutate_role', params: params);
    return RoleMutationResponseDto.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<int> loadAffectedUserCount(String roleId) async {
    final response = await _client
        .from('user_roles')
        .select('id')
        .eq('role_id', roleId);
    return response.length;
  }

  Future<List<String>> loadUserIdsForRole(String roleId) async {
    final response = await _client
        .from('user_roles')
        .select('user_id')
        .eq('role_id', roleId);
    return response.map((row) => row['user_id'] as String).toList();
  }
}
