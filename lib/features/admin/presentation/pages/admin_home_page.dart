import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final checker = getIt<PermissionChecker>();

    final tiles = <Widget>[
      if (checker.has(PermissionKeys.usersApprove))
        ListTile(
          leading: const Icon(Icons.how_to_reg_outlined),
          title: Text(l10n.admin_tile_account_approvals),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.adminApprovals),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.admin_home_title)),
      body: tiles.isEmpty
          ? _EmptyState(l10n: l10n)
          : ListView(children: tiles),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.admin_home_empty_title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.admin_home_empty_body,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
