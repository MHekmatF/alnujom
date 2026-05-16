import 'package:flutter/material.dart';

import '../../domain/entities/role_assignment_summary.dart';

class AssignedRoleRow extends StatelessWidget {
  const AssignedRoleRow({
    required this.row,
    required this.showRemoveAffordance,
    required this.onRemove,
    super.key,
  });

  final RoleAssignmentSummary row;
  final bool showRemoveAffordance;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final title = row.displayName[locale]?.trim().isNotEmpty == true
        ? row.displayName[locale]!
        : row.displayName['en']?.trim().isNotEmpty == true
        ? row.displayName['en']!
        : row.roleKey;

    return ListTile(
      title: Text(title),
      subtitle: Text(row.roleKey),
      trailing: showRemoveAffordance
          ? IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
            )
          : null,
    );
  }
}
