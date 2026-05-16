import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/role_assignment_result.dart';
import '../../domain/entities/role_assignment_summary.dart';
import '../../domain/entities/user_search_result.dart';
import '../../domain/failures.dart';
import '../../domain/repositories/user_search_repository.dart';
import '../datasources/supabase_user_search_datasource.dart';
import '../dtos/assign_role_request_dto.dart';

@LazySingleton(as: UserSearchRepository)
class UserSearchRepositoryImpl implements UserSearchRepository {
  UserSearchRepositoryImpl(this._ds, this._logger);

  static const _tag = 'UserSearchRepositoryImpl';

  final SupabaseUserSearchDataSource _ds;
  final AppLogger _logger;

  @override
  Future<List<UserSearchResult>> searchUsers(String query) async {
    try {
      final users = await _ds.searchUsers(query);
      return users.map((user) => user.toEntity()).toList();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestException(error, stackTrace, _Operation.assign);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<List<RoleAssignmentSummary>> loadUserAssignments(String userId) async {
    try {
      final roles = await _ds.loadUserAssignments(userId);
      return roles.map((role) => role.toEntity()).toList();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestException(error, stackTrace, _Operation.assign);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<RoleAssignmentResult> assign({
    required String targetUserId,
    required String targetRoleId,
    String? confirmationToken,
  }) async {
    try {
      return (await _ds.assign(
        AssignRoleRequestDto(
          targetUserId: targetUserId,
          targetRoleId: targetRoleId,
          confirmationToken: confirmationToken,
        ),
      )).toEntity();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestException(error, stackTrace, _Operation.assign);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<RoleAssignmentResult> revoke({
    required String targetUserId,
    required String targetRoleId,
  }) async {
    try {
      return (await _ds.revoke(
        targetUserId: targetUserId,
        targetRoleId: targetRoleId,
      )).toEntity();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestException(error, stackTrace, _Operation.revoke);
    } on Object catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  SuperAdminFailure _mapPostgrestException(
    PostgrestException error,
    StackTrace stackTrace,
    _Operation operation,
  ) {
    _logger.warning(
      'Super-admin assignment data error.',
      error: error,
      stackTrace: stackTrace,
      tag: _tag,
    );
    final code = error.code ?? '';
    final msg = error.message;
    if (code == '42501' && msg.contains('super_admin grant confirmation')) {
      return const SuperAdminGrantConfirmationFailedFailure();
    }
    if (code == '42501' && msg.contains('super_admin self-revoke')) {
      return const SuperAdminSelfRevokeForbiddenFailure();
    }
    if (code == '42501') {
      return operation == _Operation.revoke
          ? const RevokePermissionDeniedFailure()
          : const AssignPermissionDeniedFailure();
    }
    if (code == '23505') return const UserAlreadyHoldsRoleFailure();
    if (code == '02000') return const UserDoesNotHoldRoleFailure();
    return BackendFailure(msg, cause: error, stackTrace: stackTrace);
  }

  BackendFailure _mapError(Object error, StackTrace stackTrace) {
    _logger.warning(
      'Super-admin assignment data error.',
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

enum _Operation { assign, revoke }
