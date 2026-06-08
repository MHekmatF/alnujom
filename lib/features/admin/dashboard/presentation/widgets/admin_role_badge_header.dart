// Phase 25 uplift v2 — admin role badge header.
//
// A premium identity band for the admin hub: a shield glyph + a localized
// "Admin Console" title + a role pill derived purely from the cached
// PermissionChecker set (Super Admin if any super-admin key is held, otherwise
// Administrator). No new datasource — behaviour-preserving.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/security/permission_checker.dart';
import '../../../../../core/security/permission_keys.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../l10n/app_localizations.dart';

class AdminRoleBadgeHeader extends StatelessWidget {
  const AdminRoleBadgeHeader({required this.checker, super.key});

  final PermissionChecker checker;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;

    final isSuperAdmin = checker.any(PermissionKeys.superAdminCategoryKeys);
    final roleLabel = isSuperAdmin
        ? l10n.adminRoleBadgeSuperAdmin
        : l10n.adminRoleBadgeAdministrator;
    final accent = isSuperAdmin ? colors.accent : colors.primary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: appRadius(AppRadii.lg),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            accent.withValues(alpha: 0.14),
            colors.primary.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(LucideIcons.shield, color: accent, size: AppSpacing.xl),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.adminConsoleHeaderTitle,
                  style: styles.titleLarge.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.adminConsoleHeaderSubtitle,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: appRadius(AppRadii.pill),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Text(
              roleLabel,
              style: styles.labelMedium.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
