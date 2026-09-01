// lib/features/agency/presentation/widgets/agency_member_tile.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T050).
// One roster row: display name / phone + role chip + (admin-only) role toggle
// and remove actions. The owner row is protected (no role/remove actions).
// Phase 2 tokens only; no inline hex/font-size/padding.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final roleLabel = member.role.isAdmin
        ? l10n.agency_role_admin
        : l10n.agency_role_agent;

    final title = member.displayName?.trim().isNotEmpty == true
        ? member.displayName!
        : (member.phone ?? member.userId);

    final showActions = canManage && !isOwner;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Avatar circle (brand-tinted), matching the profile-header idiom.
          Container(
            width: AppSpacing.xxxl,
            height: AppSpacing.xxxl,
            alignment: AlignmentDirectional.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer,
            ),
            child: Icon(
              LucideIcons.user_round,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    // Soft tonal role pill (token-clean Chip replacement).
                    Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: appRadius(AppRadii.pill),
                      ),
                      child: Text(
                        roleLabel,
                        style: styles.labelMedium.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (member.phone != null && member.displayName != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          member.phone!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.bodyMedium.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (showActions)
            PopupMenuButton<String>(
              // Batch-2: Lucide glyph + token popup surface/shape, matching the
              // DS ListingViewModeSwitcher menu.
              icon: Icon(
                LucideIcons.ellipsis_vertical,
                color: colors.textMuted,
              ),
              position: PopupMenuPosition.under,
              color: colors.card,
              shape: RoundedRectangleBorder(
                borderRadius: appRadius(AppRadii.lg),
                side: BorderSide(color: colors.outline),
              ),
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
            ),
        ],
      ),
    );
  }
}
