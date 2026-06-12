import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/loading_state.dart';
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
    final canManage = getIt<PermissionChecker>().has(
      PermissionKeys.permissionsManage,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.superAdminRolesListTitle),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(LucideIcons.user_plus),
              tooltip: l10n.superAdminAssignRoleTitle,
              // push (not go) so the back stack to the admin dashboard is kept.
              onPressed: () => context.push(AppRoutes.superAdminAssign),
            ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () async {
                final created = await context.push<bool>(
                  AppRoutes.superAdminRoleCreate,
                );
                if (created == true && context.mounted) {
                  context.read<RolesListBloc>().add(const RefreshRoles());
                }
              },
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: BlocBuilder<RolesListBloc, RolesListState>(
        builder: (context, state) {
          return switch (state) {
            RolesListInitial() ||
            RolesListLoading() => const _RolesListSkeleton(),
            RolesListLoadFailure(:final failure) => Center(
              child: Text(failure.message, textAlign: TextAlign.center),
            ),
            RolesListLoaded(:final roles) => RefreshIndicator(
              onRefresh: () async =>
                  context.read<RolesListBloc>().add(const RefreshRoles()),
              child: ListView.separated(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                itemCount: roles.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final role = roles[index];
                  return RoleCard(
                    role: role,
                    // push (not go) so back returns here / to the admin
                    // dashboard; refresh on return to reflect any edits.
                    onTap: () async {
                      await context.push(
                        '${AppRoutes.superAdminRoles}/${role.roleId}',
                      );
                      if (context.mounted) {
                        context.read<RolesListBloc>().add(const RefreshRoles());
                      }
                    },
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
      if (!context.mounted) return;
      AppToast.error(context, l10n.errorRoleHasUsers(1));
    } on SuperAdminFailure catch (failure) {
      if (!context.mounted) return;
      AppToast.error(context, failure.message);
    }
  }
}

/// Shimmer placeholder rows shown while the roles list loads.
class _RolesListSkeleton extends StatelessWidget {
  const _RolesListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const SizedBox(
        height: AppSpacing.xxxl + AppSpacing.xl,
        child: LoadingState.card(),
      ),
    );
  }
}
