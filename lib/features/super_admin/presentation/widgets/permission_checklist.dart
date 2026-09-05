import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_checkbox.dart';
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final groups = <String, List<PermissionCatalogEntry>>{};
    for (final permission in catalog) {
      groups.putIfAbsent(permission.category, () => []).add(permission);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isReadOnly)
          AppSurface(
            color: colors.surfaceVariant,
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  LucideIcons.lock,
                  size: AppSpacing.xl,
                  color: colors.textMuted,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.superAdminPermissionsLocked,
                    style: styles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        for (final entry in groups.entries) ...[
          PermissionCategoryHeader(category: entry.key),
          for (final permission in entry.value)
            _PermissionRow(
              permission: permission,
              selected: selectedKeys.contains(permission.key),
              onToggle: isReadOnly ? null : () => onToggle(permission.key),
            ),
        ],
      ],
    );
  }
}

/// A branded checkbox row (leading checkbox, description, muted key) —
/// replaces the stock [CheckboxListTile].
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.selected,
    required this.onToggle,
  });

  final PermissionCatalogEntry permission;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: MergeSemantics(
            child: Row(
              children: [
                // Batch-2 a11y: the bare Checkbox sat in a ~40dp slot; the DS
                // AppCheckbox reserves the 48dp minimum tap target and takes
                // its enabled state from the read-only gate.
                AppCheckbox(
                  value: selected,
                  enabled: onToggle != null,
                  onChanged: (_) => onToggle?.call(),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Plan A33 — the database's Arabic text on an Arabic
                        // screen; English otherwise; the key as last resort.
                        permission.labelFor(
                          Localizations.localeOf(context).languageCode,
                        ),
                        style: styles.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        permission.key,
                        style: styles.labelMedium.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
