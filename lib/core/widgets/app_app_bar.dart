import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import 'dimens.dart';

enum AppAppBarVariant { defaultBar, withBack, withSearch, transparentOnImage }

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    required this.title,
    this.variant = AppAppBarVariant.defaultBar,
    this.onBack,
    this.onSearch,
    this.actions = const [],
    super.key,
  });

  final String title;
  final AppAppBarVariant variant;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final foreground = variant == AppAppBarVariant.transparentOnImage
        ? colors.onPrimary
        : colors.onSurface;
    final isTransparent = variant == AppAppBarVariant.transparentOnImage;
    return AppBar(
      title: Text(title, style: styles.titleLarge.copyWith(color: foreground)),
      backgroundColor: isTransparent ? Colors.transparent : colors.surface,
      foregroundColor: foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: isTransparent ? 0 : AppDimens.strokeThin,
      leading: variant == AppAppBarVariant.withBack
          ? IconButton(
              onPressed: onBack,
              icon: Icon(
                isRtl ? LucideIcons.chevron_right : LucideIcons.chevron_left,
              ),
            )
          : null,
      actions: [
        if (variant == AppAppBarVariant.withSearch)
          IconButton(onPressed: onSearch, icon: const Icon(LucideIcons.search)),
        ...actions,
      ],
    );
  }
}
