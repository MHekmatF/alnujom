import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../l10n/app_localizations.dart';

class PermissionCategoryHeader extends StatelessWidget {
  const PermissionCategoryHeader({required this.category, super.key});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        _resolveLocalized(context),
        style: AppTextStyles.of(context).titleMedium,
      ),
    );
  }

  String _resolveLocalized(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (category) {
      'users' => l10n.permissionCategoryUsers,
      'listings' => l10n.permissionCategoryListings,
      'roles' => l10n.permissionCategoryRoles,
      'locations' => l10n.permissionCategoryLocations,
      'currencies' => l10n.permissionCategoryCurrencies,
      'ads' => l10n.permissionCategoryAds,
      'reports' => l10n.permissionCategoryReports,
      'agencies' => l10n.permissionCategoryAgencies,
      'settings' => l10n.permissionCategorySettings,
      'audit' => l10n.permissionCategoryAudit,
      'inquiries' => l10n.permissionCategoryInquiries,
      'permissions' => l10n.permissionCategoryPermissions,
      _ => category,
    };
  }
}
