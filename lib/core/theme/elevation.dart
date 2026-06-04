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

    // Phase 25 (Claude Design) — dark mode keeps a hairline border for crisp
    // separation AND adds real soft shadows so cards lift off the dark surface.
    if (isDark) {
      return AppElevation._(
        level0: const [],
        level1: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
        level2: const [
          BoxShadow(
            color: Color(0x73000000),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
        level3: const [
          BoxShadow(
            color: Color(0x8C000000),
            offset: Offset(0, 16),
            blurRadius: 38,
          ),
        ],
        hairline: Border.all(color: colors.outline, width: 1),
      );
    }

    // Light mode — soft navy-tinted shadows (Claude `--shadow-sm/md/lg`,
    // base color #102A43).
    return const AppElevation._(
      level0: [],
      level1: [
        BoxShadow(
          color: Color(0x0F102A43),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
      ],
      level2: [
        BoxShadow(
          color: Color(0x14102A43),
          offset: Offset(0, 4),
          blurRadius: 14,
        ),
        BoxShadow(
          color: Color(0x0A102A43),
          offset: Offset(0, 1),
          blurRadius: 4,
        ),
      ],
      level3: [
        BoxShadow(
          color: Color(0x24102A43),
          offset: Offset(0, 14),
          blurRadius: 34,
        ),
        BoxShadow(
          color: Color(0x0F102A43),
          offset: Offset(0, 4),
          blurRadius: 10,
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
