import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// DC underline tabs rendered on the blue brand crown — the Home purpose tabs
/// (للبيع/للإيجار/إيجار يومي), the Search purpose tabs, and the Saved tabs all
/// share this treatment (`AlNujom.dc.html`).
///
/// Selected = white text + a 3px white underline; unselected = translucent
/// white. Start-aligned with a fixed inter-tab gap, matching the DC crown.
class CrownUnderlineTabs extends StatelessWidget {
  const CrownUnderlineTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.fontSize = 15,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// DC uses 15 on Home, 14 on Search/Saved.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xl),
            _CrownTab(
              label: labels[i],
              selected: i == selectedIndex,
              fontSize: fontSize,
              onTap: () => onChanged(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _CrownTab extends StatelessWidget {
  const _CrownTab({
    required this.label,
    required this.selected,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? colors.onBrandHeader : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: styles.titleMedium.copyWith(
            fontSize: fontSize,
            color: selected
                ? colors.onBrandHeader
                : colors.onBrandHeader.withValues(alpha: 0.6),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
