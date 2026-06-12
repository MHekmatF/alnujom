import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/role_assignment_summary.dart';
import '../../domain/entities/role_with_counts.dart';
import '../../domain/entities/user_search_result.dart';
import '../bloc/assign_role_bloc.dart';
import '../widgets/assigned_role_row.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/super_admin_grant_confirmation_dialog.dart';
import '../widgets/user_search_field.dart';

class AssignRolePage extends StatelessWidget {
  const AssignRolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AssignRoleBloc>(
      create: (_) => getIt<AssignRoleBloc>(),
      child: const _AssignRoleView(),
    );
  }
}

class _AssignRoleView extends StatelessWidget {
  const _AssignRoleView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<AssignRoleBloc, AssignRoleState>(
      listenWhen: (previous, current) => previous.action != current.action,
      listener: _handleAction,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.superAdminAssignRoleTitle)),
        body: BlocBuilder<AssignRoleBloc, AssignRoleState>(
          builder: (context, state) {
            final ready = state is AssignRoleReady ? state : null;
            return ListView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              children: [
                UserSearchField(
                  hintText: l10n.userSearchPlaceholder,
                  onChanged: (query) => context.read<AssignRoleBloc>().add(
                    UpdateUserQuery(query),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (state is AssignRoleSearching)
                  const AppSpinner()
                else if (ready != null && ready.results.isEmpty)
                  Text(l10n.userSearchEmptyResults)
                else if (ready != null)
                  for (final user in ready.results)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: AppSpacing.sm,
                      ),
                      child: _UserResultRow(
                        title:
                            user.fullName ??
                            user.username ??
                            user.phone ??
                            user.userId,
                        subtitle: user.phone ?? user.username ?? user.userId,
                        onTap: () => context.read<AssignRoleBloc>().add(
                          SelectUser(user),
                        ),
                      ),
                    ),
                if (ready?.selectedUser != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _UserRoleDrawer(state: ready!),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    AssignRoleState state,
  ) async {
    final action = state.action;
    if (action == null) return;
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<AssignRoleBloc>();
    if (action is NeedSuperAdminConfirmation) {
      final token = await showSuperAdminGrantConfirmationDialog(
        context,
        targetUser: action.targetUser,
      );
      if (token != null && context.mounted) {
        bloc.add(
          GrantSuperAdminRole(
            targetUserId: action.targetUser.userId,
            targetRoleId: action.targetRoleId,
            confirmationToken: token,
          ),
        );
      }
    } else if (action is AssignRoleSucceeded) {
      AppToast.success(context, l10n.assignRoleSucceeded);
    } else if (action is RevokeRoleSucceeded) {
      AppToast.success(context, l10n.revokeRoleSucceeded);
    } else if (action is AssignRoleFailed) {
      AppToast.error(context, action.failure.message);
    }
    bloc.add(const ClearAssignRoleAction());
  }
}

class _UserRoleDrawer extends StatelessWidget {
  const _UserRoleDrawer({required this.state});

  final AssignRoleReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedUser = state.selectedUser!;
    final canManage = getIt<PermissionChecker>().has(
      PermissionKeys.permissionsManage,
    );
    return AppSurface(
      radius: AppRadii.lg,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            selectedUser.fullName ??
                selectedUser.username ??
                selectedUser.phone ??
                selectedUser.userId,
            style: AppTextStyles.of(context).titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.loadingDrawer)
            const AppSpinner()
          else
            for (final role in state.currentRoles)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppSpacing.sm,
                ),
                child: AssignedRoleRow(
                  row: role,
                  showRemoveAffordance:
                      canManage &&
                      _shouldShowRemoveAffordance(
                        context,
                        role,
                        selectedUser.userId,
                      ),
                  onRemove: () => _confirmRevoke(context, selectedUser, role),
                ),
              ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: l10n.actionGrant,
              icon: LucideIcons.plus,
              onPressed: () => _pickRole(context, selectedUser),
            ),
          ],
        ],
      ),
    );
  }

  bool _shouldShowRemoveAffordance(
    BuildContext context,
    RoleAssignmentSummary row,
    String selectedUserId,
  ) {
    final authState = getIt<AuthBloc>().state;
    final selfUserId = authState is Authenticated
        ? authState.profile.userId
        : null;
    return !(selfUserId == selectedUserId && row.roleKey == 'super_admin');
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    UserSearchResult user,
    RoleAssignmentSummary role,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmationDialog(
      context,
      title: l10n.confirmRevokeRoleTitle,
      body: l10n.confirmRevokeRoleBody,
      confirmButtonLabel: l10n.actionRevoke,
      cancelButtonLabel: l10n.actionCancel,
      destructive: true,
    );
    if (confirmed == true && context.mounted) {
      context.read<AssignRoleBloc>().add(
        RevokeRole(targetUserId: user.userId, targetRoleId: role.roleId),
      );
    }
  }

  Future<void> _pickRole(BuildContext context, UserSearchResult user) async {
    final l10n = AppLocalizations.of(context)!;
    final heldRoleIds = state.currentRoles.map((role) => role.roleId).toSet();
    final availableRoles = state.roles
        .where((role) => !heldRoleIds.contains(role.roleId))
        .toList();
    final picked = await showModalBottomSheet<RoleWithCounts>(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        children: [
          for (final role in availableRoles)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: _RolePickRow(
                title: _localizedRoleName(context, role),
                subtitle: role.roleKey,
                onTap: () => Navigator.of(context).pop(role),
              ),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked.roleKey == 'super_admin') {
      context.read<AssignRoleBloc>().add(
        GrantRole(targetUserId: user.userId, targetRoleId: picked.roleId),
      );
      return;
    }
    final confirmed = await showConfirmationDialog(
      context,
      title: l10n.confirmGrantRoleTitle,
      body: l10n.confirmGrantRoleBody,
      confirmButtonLabel: l10n.actionGrant,
      cancelButtonLabel: l10n.actionCancel,
    );
    if (confirmed == true && context.mounted) {
      context.read<AssignRoleBloc>().add(
        GrantRole(targetUserId: user.userId, targetRoleId: picked.roleId),
      );
    }
  }

  String _localizedRoleName(BuildContext context, RoleWithCounts role) {
    final locale = Localizations.localeOf(context).languageCode;
    return role.displayName[locale]?.trim().isNotEmpty == true
        ? role.displayName[locale]!
        : role.displayName['en']?.trim().isNotEmpty == true
        ? role.displayName['en']!
        : role.roleKey;
  }
}

/// Branded tappable row (tinted leading glyph, name, muted detail, directional
/// chevron) — replaces the stock [ListTile] in the search results and the
/// role-pick bottom sheet.
class _BrandedPickRow extends StatelessWidget {
  const _BrandedPickRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        onTap: onTap,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.xxl + AppSpacing.lg,
              height: AppSpacing.xxl + AppSpacing.lg,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: colors.primary, size: AppSpacing.xl),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? LucideIcons.chevron_left
                  : LucideIcons.chevron_right,
              size: AppSpacing.xl,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserResultRow extends StatelessWidget {
  const _UserResultRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BrandedPickRow(
      icon: LucideIcons.user,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

class _RolePickRow extends StatelessWidget {
  const _RolePickRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BrandedPickRow(
      icon: LucideIcons.shield,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}
