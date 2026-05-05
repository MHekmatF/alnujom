import 'package:flutter/material.dart';

import 'colors.dart';

final class AppElevation {
  const AppElevation._({
    required this.level0,
    required this.level1,
    required this.level2,
    required this.level3,
    required this.hairline,
  });

  factory AppElevation.of(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return AppElevation._(
        level0: const [],
        level1: const [],
        level2: const [],
        level3: const [],
        hairline: Border.all(color: colors.outline, width: 1),
      );
    }

    return const AppElevation._(
      level0: [],
      level1: [
        BoxShadow(
          color: Color(0x0F0F172A),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
      ],
      level2: [
        BoxShadow(
          color: Color(0x140F172A),
          offset: Offset(0, 2),
          blurRadius: 6,
        ),
      ],
      level3: [
        BoxShadow(
          color: Color(0x1A0F172A),
          offset: Offset(0, 4),
          blurRadius: 12,
        ),
      ],
      hairline: Border.fromBorderSide(BorderSide.none),
    );
  }

  final List<BoxShadow> level0;
  final List<BoxShadow> level1;
  final List<BoxShadow> level2;
  final List<BoxShadow> level3;
  final BoxBorder hairline;
}
