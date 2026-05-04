import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '_widget_support.dart';

class LocationSelector extends StatelessWidget {
  const LocationSelector({
    required this.city,
    this.area,
    this.enabled = true,
    this.onTap,
    super.key,
  });

  final String city;
  final String? area;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = area == null ? city : '$city / $area';
    return AppSurface(
      onTap: enabled ? onTap : null,
      opacity: enabled ? 1 : 0.5,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: kAppMinTouchTarget,
          minHeight: kAppMinTouchTarget,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.map_pin, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: AppSectionText(text: text, maxLines: 1)),
            const SizedBox(width: AppSpacing.sm),
            Icon(LucideIcons.chevron_down, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
