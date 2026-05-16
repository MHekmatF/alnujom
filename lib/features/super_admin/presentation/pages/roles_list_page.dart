import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/role_with_counts.dart';
import '../../domain/failures.dart';
import '../../domain/usecases/delete_role.dart';
import '../../domain/usecases/load_affected_user_count.dart';
import '../../domain/usecases/load_role_detail.dart';
import '../../domain/usecases/load_role_user_ids.dart';
import '../../domain/usecases/revoke_role_from_user.dart';
import '../bloc/roles_list_bloc.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/role_card.dart';

class RolesListPage extends StatelessWidget {
  const RolesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RolesListBloc>(
      create: (_) => getIt<RolesListBloc>()..add(const LoadRoles()),
      child: const _RolesListView(),
    );
  }
}

class _RolesListView extends StatelessWidget {
  const _RolesListView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canCreate = getIt<PermissionChecker>().has(
      PermissionKeys.rolesCreate,
    );
    final canDelete = getIt<PermissionChecker>().has(
      PermissionKeys.rolesDelete,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.superAdminRolesListTitle)),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => context.go(AppRoutes.superAdminRoleCreate),
              // TODO(US4): Replace placeholder route target with CreateRolePage implementation.
              child: const Icon(Icons.add),
            )
          : null,
      body: BlocBuilder<RolesListBloc, RolesListState>(
        builder: (context, state) {
          return switch (state) {
            RolesListInitial() || RolesListLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            RolesListLoadFailure(:final failure) => Center(
              child: Text(failure.message, textAlign: TextAlign.center),
            ),
            RolesListLoaded(:final roles) => RefreshIndicator(
              onRefresh: () async =>
                  context.read<RolesListBloc>().add(const RefreshRoles()),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: roles.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final role = roles[index];
                  return RoleCard(
                    role: role,
                    onTap: () => context.go(
                      '${AppRoutes.superAdminRoles}/${role.roleId}',
                    ),
                    onLongPress: canDelete && !role.isSystem
                        ? () => _deleteRole(context, role)
                        : null,
                  );
                },
              ),
            ),
          };
        },
      ),
    );
  }

  Future<void> _deleteRole(BuildContext context, RoleWithCounts role) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await getIt<LoadAffectedUserCount>()(role.roleId);
      if (!context.mounted) return;
      final confirmed = await showConfirmationDialog(
        context,
        title: l10n.confirmDeleteRoleTitle,
        body: count == 0
            ? l10n.confirmDeleteRoleBody
            : l10n.confirmDeleteRoleBodyWithUsers(count),
        confirmButtonLabel: l10n.actionDelete,
        cancelButtonLabel: l10n.actionCancel,
        destructive: true,
      );
      if (confirmed != true || !context.mounted) return;

      var expectedUpdatedAt = role.updatedAt;
      if (count > 0) {
        final userIds = await getIt<LoadRoleUserIds>()(role.roleId);
        for (final userId in userIds) {
          await getIt<RevokeRoleFromUser>()(
            targetUserId: userId,
            targetRoleId: role.roleId,
          );
        }
        expectedUpdatedAt = (await getIt<LoadRoleDetail>()(
          role.roleId,
        )).updatedAt;
      }

      await getIt<DeleteRole>()(
        roleId: role.roleId,
        expectedUpdatedAt: expectedUpdatedAt,
      );
      if (!context.mounted) return;
      context.read<RolesListBloc>().add(const RefreshRoles());
    } on RoleHasUsersFailure {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.errorRoleHasUsers(1))),
      );
    } on SuperAdminFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}
