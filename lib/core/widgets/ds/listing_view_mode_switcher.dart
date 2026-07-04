import 'package:flutter/material.dart';

import '../../settings/listing_view_mode.dart';
import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../../l10n/app_localizations.dart';
import '../_widget_support.dart';

/// Phase 035 — the مريح / متوازن / مضغوط density switcher shown above the feed
/// on Home and Search. A 40×40 outlined button whose glyph reflects the current
/// [ListingViewMode]; tapping opens a popover to pick a mode. The choice is
/// persisted process-wide via [ListingViewModePref], so every feed reacts.
class ListingViewModeSwitcher extends StatelessWidget {
  const ListingViewModeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ValueListenableBuilder<ListingViewMode>(
      valueListenable: ListingViewModePref.notifier,
      builder: (context, mode, _) {
        return PopupMenuButton<ListingViewMode>(
          tooltip: AppLocalizations.of(context)!.view_mode_title,
          position: PopupMenuPosition.under,
          color: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: appRadius(AppRadii.lg),
            side: BorderSide(color: colors.outline),
          ),
          onSelected: ListingViewModePref.set,
          itemBuilder: (context) => [
            for (final m in ListingViewMode.values)
              PopupMenuItem<ListingViewMode>(
                value: m,
                child: _ModeRow(mode: m, selected: m == mode),
              ),
          ],
          child: Container(
            width: AppSpacing.xxl,
            height: AppSpacing.xxl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: appRadius(AppRadii.md),
              border: Border.all(color: colors.primary, width: 1.5),
            ),
            child: Icon(_iconFor(mode), size: AppSpacing.xl, color: colors.primary),
          ),
        );
      },
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.mode, required this.selected});

  final ListingViewMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final tint = selected ? colors.primary : colors.onSurface;

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          Icon(_iconFor(mode), size: AppSpacing.xl, color: tint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title(l10n, mode),
                  style: styles.labelLarge.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _desc(l10n, mode),
                  style: styles.labelMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.check_rounded, size: AppSpacing.lg, color: colors.primary),
          ],
        ],
      ),
    );
  }

  String _title(AppLocalizations l10n, ListingViewMode m) => switch (m) {
    ListingViewMode.comfortable => l10n.view_mode_comfortable,
    ListingViewMode.balanced => l10n.view_mode_balanced,
    ListingViewMode.compact => l10n.view_mode_compact,
  };

  String _desc(AppLocalizations l10n, ListingViewMode m) => switch (m) {
    ListingViewMode.comfortable => l10n.view_mode_comfortable_desc,
    ListingViewMode.balanced => l10n.view_mode_balanced_desc,
    ListingViewMode.compact => l10n.view_mode_compact_desc,
  };
}

IconData _iconFor(ListingViewMode mode) => switch (mode) {
  ListingViewMode.comfortable => Icons.view_agenda_outlined,
  ListingViewMode.balanced => Icons.view_day_outlined,
  ListingViewMode.compact => Icons.view_list_outlined,
};
