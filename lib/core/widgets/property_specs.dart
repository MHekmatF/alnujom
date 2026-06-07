import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../../l10n/app_localizations.dart';

/// Phase 25 uplift v2 — compact key-facts row (beds · baths · area) for property
/// cards. Renders only the specs that are present (land has no rooms/baths).
/// RTL-safe; numbers render in the active locale's numerals.
class PropertySpecsRow extends StatelessWidget {
  const PropertySpecsRow({
    super.key,
    this.rooms,
    this.bathrooms,
    this.areaSize,
    this.color,
  });

  final int? rooms;
  final int? bathrooms;
  final double? areaSize;

  /// Foreground for icons + text. Defaults to the muted on-surface tone.
  final Color? color;

  static bool hasAnyOf({int? rooms, int? bathrooms, double? areaSize}) =>
      rooms != null || bathrooms != null || areaSize != null;

  bool get hasAny =>
      hasAnyOf(rooms: rooms, bathrooms: bathrooms, areaSize: areaSize);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final numFmt = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final fg = color ?? colors.onSurfaceVariant;
    final textStyle = styles.labelMedium.copyWith(color: fg);

    final items = <Widget>[];
    if (rooms != null) {
      items.add(
        _SpecItem(
          icon: LucideIcons.bed,
          value: numFmt.format(rooms),
          semantic: '${numFmt.format(rooms)} ${l10n.spec_rooms_label}',
          style: textStyle,
          color: fg,
        ),
      );
    }
    if (bathrooms != null) {
      items.add(
        _SpecItem(
          icon: LucideIcons.bath,
          value: numFmt.format(bathrooms),
          semantic: '${numFmt.format(bathrooms)} ${l10n.spec_baths_label}',
          style: textStyle,
          color: fg,
        ),
      );
    }
    if (areaSize != null) {
      final area = '${_formatArea(numFmt, areaSize!)} ${l10n.spec_area_unit}';
      items.add(
        _SpecItem(
          icon: LucideIcons.ruler,
          value: area,
          semantic: '${l10n.spec_area_label} $area',
          style: textStyle,
          color: fg,
        ),
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) children.add(const SizedBox(width: AppSpacing.md));
      children.add(items[i]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  static String _formatArea(NumberFormat fmt, double value) {
    if (value == value.roundToDouble()) return fmt.format(value.round());
    return fmt.format(double.parse(value.toStringAsFixed(1)));
  }
}

class _SpecItem extends StatelessWidget {
  const _SpecItem({
    required this.icon,
    required this.value,
    required this.semantic,
    required this.style,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String semantic;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantic,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSpacing.lg, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(value, style: style),
        ],
      ),
    );
  }
}
