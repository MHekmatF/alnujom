import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/staggered_list_item.dart';
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

    return DcCrownScaffold(
      title: l10n.superAdminRolesListTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      actions: [
        if (canManage)
          IconButton(
            icon: Icon(
              LucideIcons.user_plus,
              color: AppColors.of(context).onBrandHeader,
            ),
            tooltip: l10n.superAdminAssignRoleTitle,
            // push (not go) so the back stack to the admin dashboard is kept.
            onPressed: () => context.push(AppRoutes.superAdminAssign),
          ),
      ],
      floatingActionButton: canCreate
          ? FloatingActionButton(
              // Batch-2 a11y: the icon-only FAB had no accessible name.
              tooltip: l10n.superAdminCreateRoleTitle,
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
            // Batch-2: the bare centred Text error -> the shared ErrorState,
            // which adds the glyph badge and a Retry (there was none).
            RolesListLoadFailure(:final failure) => ErrorState(
              title: l10n.superAdminRolesListTitle,
              message: failure.message,
              onRetry: () =>
                  context.read<RolesListBloc>().add(const RefreshRoles()),
            ),
            RolesListLoaded(:final roles) =>
              roles.isEmpty
                  // Batch-2: the loaded-but-empty case rendered a blank sheet.
                  ? EmptyState(
                      icon: LucideIcons.shield,
                      headline: l10n.superAdminRolesListTitle,
                      body: l10n.superAdminCreateRoleTitle,
                    )
                  : RefreshIndicator(
                      onRefresh: () async => context.read<RolesListBloc>().add(
                        const RefreshRoles(),
                      ),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                        itemCount: roles.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final role = roles[index];
                          return StaggeredListItem(
                            index: index,
                            child: RoleCard(
                              role: role,
                              // push (not go) so back returns here / to the admin
                              // dashboard; refresh on return to reflect edits.
                              onTap: () async {
                                await context.push(
                                  '${AppRoutes.superAdminRoles}/${role.roleId}',
                                );
                                if (context.mounted) {
                                  context.read<RolesListBloc>().add(
                                    const RefreshRoles(),
                                  );
                                }
                              },
                              onLongPress: canDelete && !role.isSystem
                                  ? () => _deleteRole(context, role)
                                  : null,
                            ),
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
