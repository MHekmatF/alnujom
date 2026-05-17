import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/area.dart';
import 'hidden_badge.dart';

enum _CardAction { edit, toggleActive, delete }

class AreaCard extends StatelessWidget {
  const AreaCard({
    super.key,
    required this.area,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Area area;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final description = area.description?[locale.languageCode];

    return Card(
      child: ListTile(
        leading: const Icon(Icons.place_outlined),
        title: Text(area.localizedName(locale)),
        subtitle: description != null && description.isNotEmpty
            ? Text(description)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!area.isActive) const HiddenBadge(),
            PopupMenuButton<_CardAction>(
              onSelected: (action) => switch (action) {
                _CardAction.edit => onEdit(),
                _CardAction.toggleActive => onToggleActive(),
                _CardAction.delete => onDelete(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _CardAction.edit,
                  child: Text(l10n.editAffordance),
                ),
                PopupMenuItem(
                  value: _CardAction.toggleActive,
                  child: Text(l10n.isActiveToggleLabel),
                ),
                PopupMenuItem(
                  value: _CardAction.delete,
                  child: Text(l10n.deleteAffordance),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
