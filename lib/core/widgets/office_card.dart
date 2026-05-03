import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';
import 'app_badge.dart';
import 'loading_state.dart';

class OfficeCard extends StatelessWidget {
  const OfficeCard({
    required this.name,
    required this.listingsCount,
    this.logo,
    this.verified = false,
    this.visited = false,
    this.loading = false,
    this.onVisit,
    super.key,
  });

  final String name;
  final int listingsCount;
  final Widget? logo;
  final bool verified;
  final bool visited;
  final bool loading;
  final VoidCallback? onVisit;

  @override
  Widget build(BuildContext context) {
    if (loading) return const LoadingState.row();
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return AppSurface(
      onTap: onVisit,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.primaryContainer,
            child: logo ?? Icon(LucideIcons.building, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: styles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (verified) const SizedBox(width: AppSpacing.xs),
                    if (verified)
                      const AppBadge(
                        label: 'Verified',
                        variant: AppBadgeVariant.verifiedOffice,
                      ),
                  ],
                ),
                Text('$listingsCount listings', style: styles.bodyMedium),
              ],
            ),
          ),
          Icon(
            visited ? LucideIcons.check : LucideIcons.arrow_up_right,
            color: colors.primary,
          ),
        ],
      ),
    );
  }
}
