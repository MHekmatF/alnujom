import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/permission_catalog_entry.dart';
import 'permission_category_header.dart';

class PermissionChecklist extends StatelessWidget {
  const PermissionChecklist({
    required this.catalog,
    required this.selectedKeys,
    required this.onToggle,
    required this.isReadOnly,
    super.key,
  });

  final List<PermissionCatalogEntry> catalog;
  final Set<String> selectedKeys;
  final ValueChanged<String> onToggle;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = <String, List<PermissionCatalogEntry>>{};
    for (final permission in catalog) {
      groups.putIfAbsent(permission.category, () => []).add(permission);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isReadOnly)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.superAdminPermissionsLocked,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        for (final entry in groups.entries) ...[
          PermissionCategoryHeader(category: entry.key),
          for (final permission in entry.value)
            CheckboxListTile(
              value: selectedKeys.contains(permission.key),
              onChanged: isReadOnly ? null : (_) => onToggle(permission.key),
              title: Text(permission.description ?? permission.key),
              subtitle: Text(permission.key),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ],
    );
  }
}
