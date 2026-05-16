import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/assigned_role_dto.dart';
import '../dtos/assign_role_request_dto.dart';
import '../dtos/role_assignment_response_dto.dart';
import '../dtos/user_search_result_dto.dart';

@LazySingleton()
class SupabaseUserSearchDataSource {
  SupabaseUserSearchDataSource();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  Future<List<UserSearchResultDto>> searchUsers(String query) async {
    final sanitized = query.replaceAll(RegExp(r'[,;()=:*]'), '').trim();
    if (sanitized.isEmpty) return const [];

    final response = await _client
        .from('profiles')
        .select('user_id, phone, username, full_name')
        .or('phone.like.$sanitized%,username.ilike.%$sanitized%')
        .order('username', ascending: true)
        .limit(50);

    return response.map((row) => UserSearchResultDto.fromJson(row)).toList();
  }

  Future<List<AssignedRoleDto>> loadUserAssignments(String userId) async {
    final response = await _client
        .from('user_roles')
        .select('role_id, granted_at, role:roles(id, key, display_name)')
        .eq('user_id', userId)
        .order('role_id', ascending: true);

    return response.map((row) => AssignedRoleDto.fromJson(row)).toList();
  }

  Future<RoleAssignmentResponseDto> assign(AssignRoleRequestDto request) async {
    final response = await _client.rpc(
      'assign_role_to_user',
      params: request.toJson(),
    );
    return RoleAssignmentResponseDto.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<RoleAssignmentResponseDto> revoke({
    required String targetUserId,
    required String targetRoleId,
  }) async {
    final response = await _client.rpc(
      'revoke_role_from_user',
      params: {'target_user_id': targetUserId, 'target_role_id': targetRoleId},
    );
    return RoleAssignmentResponseDto.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
