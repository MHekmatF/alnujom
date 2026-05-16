import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/role_with_counts.dart';

class RoleCard extends StatelessWidget {
  const RoleCard({required this.role, required this.onTap, super.key});

  final RoleWithCounts role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final localizedName = role.displayName[locale];
    final fallbackName = role.displayName['en'];
    final title = localizedName?.trim().isNotEmpty == true
        ? localizedName!
        : fallbackName?.trim().isNotEmpty == true
        ? fallbackName!
        : role.roleKey;

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.rolePermissionsCount(role.permissionCount),
                style: theme.textTheme.bodyMedium,
              ),
              const Icon(Icons.people_outline, size: 18),
              Text('${role.userCount}', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        trailing: role.isSystem
            ? Chip(label: Text(l10n.roleBadgeSystem))
            : null,
      ),
    );
  }
}
