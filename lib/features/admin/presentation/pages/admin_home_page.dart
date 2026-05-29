import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../debug/locations_smoke_test_tile.dart';
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
      if (checker.any(const <String>[
        PermissionKeys.listingsApprove,
        PermissionKeys.listingsReject,
      ]))
        ListTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(l10n.adminTilePendingReview),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.adminListingReviewPending),
        ),
      if (checker.any(PermissionKeys.superAdminCategoryKeys))
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text(l10n.adminTileSuperAdmin),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.superAdminRoles),
        ),
      if (checker.has(PermissionKeys.inquiriesViewAll))
        ListTile(
          leading: const Icon(Icons.forum_outlined),
          title: Text(l10n.admin_inquiries_app_bar_title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.adminInquiries),
        ),
      if (checker.has(PermissionKeys.locationsManage))
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(l10n.locationsTileTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.locationsAdmin),
        ),
      if (checker.has(PermissionKeys.currenciesManage))
        ListTile(
          leading: const Icon(Icons.currency_exchange),
          title: Text(l10n.adminHomeCurrenciesTile),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.currenciesAdmin),
        ),
      // Phase 18 — reports.manage gated tile (FR-019, no hardcoded role branch).
      if (checker.has(PermissionKeys.reportsManage))
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: Text(l10n.admin_tile_reports),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.adminReports),
        ),
      if (kDebugMode) const LocationsSmokeTestTile(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.admin_home_title),
        actions: const [LocaleToggleAction()],
      ),
      body: tiles.isEmpty ? _EmptyState(l10n: l10n) : ListView(children: tiles),
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
