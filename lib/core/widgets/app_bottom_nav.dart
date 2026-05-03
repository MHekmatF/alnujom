import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'dimens.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.currentIndex,
    required this.onTabSelected,
    required this.onAddPressed,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tabs = <_BottomTab>[
      const _BottomTab('الرئيسية', LucideIcons.house),
      const _BottomTab('البحث', LucideIcons.search),
      const _BottomTab('إضافة', LucideIcons.plus),
      const _BottomTab('المفضلة', LucideIcons.heart),
      const _BottomTab('حسابي', LucideIcons.user),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i += 1)
              Expanded(
                child: InkWell(
                  onTap: i == AppDimens.bottomNavAddIndex
                      ? onAddPressed
                      : () => onTabSelected(i),
                  child: _BottomNavItem(
                    tab: tabs[i],
                    selected: currentIndex == i,
                    isAdd: i == AppDimens.bottomNavAddIndex,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.tab,
    required this.selected,
    required this.isAdd,
  });

  final _BottomTab tab;
  final bool selected;
  final bool isAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final color = selected || isAdd ? colors.primary : colors.textMuted;
    return SizedBox(
      height: AppDimens.bottomNavItemHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: AppDimens.strokeMedium,
            color: selected ? colors.primary : Colors.transparent,
          ),
          const SizedBox(height: AppSpacing.xs),
          Icon(
            tab.icon,
            color: color,
            size: isAdd ? AppDimens.bottomNavAddIconSize : AppSpacing.xl,
          ),
          Text(tab.label, style: styles.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}

final class _BottomTab {
  const _BottomTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
