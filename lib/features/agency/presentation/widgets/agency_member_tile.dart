// lib/features/agency/presentation/widgets/agency_member_tile.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T050).
// One roster row: display name / phone + role chip + (admin-only) role toggle
// and remove actions. The owner row is protected (no role/remove actions).
// Phase 2 tokens only; no inline hex/font-size/padding.
import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/agency_member.dart';
import '../../domain/entities/agency_member_role.dart';

class AgencyMemberTile extends StatelessWidget {
  const AgencyMemberTile({
    super.key,
    required this.member,
    required this.isOwner,
    required this.canManage,
    this.onRoleToggle,
    this.onRemove,
  });

  final AgencyMember member;

  /// True when this member is the agency owner (protected — no actions).
  final bool isOwner;

  /// True when the current viewer is an agency admin (actions enabled).
  final bool canManage;

  /// Called with the NEW role wire value when the admin toggles the role.
  final void Function(String role)? onRoleToggle;

  /// Called when the admin removes this member.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final roleLabel = member.role.isAdmin
        ? l10n.agency_role_admin
        : l10n.agency_role_agent;

    final title = member.displayName?.trim().isNotEmpty == true
        ? member.displayName!
        : (member.phone ?? member.userId);

    final showActions = canManage && !isOwner;

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
      ),
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(Icons.person_outline, color: scheme.onSecondaryContainer),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Chip(
            label: Text(roleLabel),
            labelStyle: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            backgroundColor: scheme.surfaceContainerHighest,
            side: BorderSide.none,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          if (member.phone != null && member.displayName != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                member.phone!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: showActions
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'toggle_role':
                    onRoleToggle?.call(
                      member.role.isAdmin
                          ? AgencyMemberRole.agent.wireValue
                          : AgencyMemberRole.admin.wireValue,
                    );
                  case 'remove':
                    onRemove?.call();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'toggle_role',
                  child: Text(
                    member.role.isAdmin
                        ? l10n.agency_role_agent
                        : l10n.agency_role_admin,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Text(l10n.agency_member_remove),
                ),
              ],
            )
          : null,
    );
  }
}
