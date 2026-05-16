import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/roles_list_bloc.dart';
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
                  );
                },
              ),
            ),
          };
        },
      ),
    );
  }
}
