import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/governorate_with_city_count.dart';
import 'hidden_badge.dart';
import 'system_row_badge.dart';

enum _CardAction { edit, toggleActive, delete }

class GovernorateCard extends StatelessWidget {
  const GovernorateCard({
    super.key,
    required this.summary,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
    this.onDelete,
  });

  final GovernorateWithCityCount summary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final gov = summary.governorate;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(gov.localizedName(locale)),
        subtitle: Text(l10n.subtitleCityCount(summary.cityCount)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gov.isSystem) const SystemRowBadge(),
            if (!gov.isActive) const HiddenBadge(),
            PopupMenuButton<_CardAction>(
              onSelected: (action) => switch (action) {
                _CardAction.edit => onEdit(),
                _CardAction.toggleActive => onToggleActive(),
                _CardAction.delete => onDelete?.call(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _CardAction.edit,
                  child: Text(l10n.editAffordance),
                ),
                PopupMenuItem(
                  value: _CardAction.toggleActive,
                  child: Text(
                    gov.isActive ? l10n.actionDeactivate : l10n.actionActivate,
                  ),
                ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: _CardAction.delete,
                    child: Text(l10n.deleteAffordance),
                  ),
              ],
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
