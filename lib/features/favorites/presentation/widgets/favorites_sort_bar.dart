// lib/features/favorites/presentation/widgets/favorites_sort_bar.dart
//
// Phase 25 uplift v2 — the inline sort control on the FavoritesPage. A small
// header row ("Sorted by …") with a token-styled dropdown that re-orders the
// saved listings client-side (recently saved / price high→low / price
// low→high) via [FavoritesPageSortChanged].
//
// Token-only; RTL-safe.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/favorites_sort.dart';
import '../bloc/favorites_page_bloc.dart';

/// A compact, right-aligned sort affordance shown above the favorites list.
class FavoritesSortBar extends StatelessWidget {
  const FavoritesSortBar({super.key, required this.sort});

  final FavoritesSort sort;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.arrow_up_down,
            size: AppSpacing.lg,
            color: colors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            l10n.favorites_sort_label,
            style: styles.labelMedium.copyWith(color: colors.textMuted),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<FavoritesSort>(
              value: sort,
              isDense: true,
              borderRadius: appRadius(AppRadii.sm),
              icon: Icon(
                LucideIcons.chevron_down,
                size: AppSpacing.lg,
                color: colors.onSurfaceVariant,
              ),
              style: styles.labelLarge.copyWith(color: colors.onSurface),
              items: [
                DropdownMenuItem<FavoritesSort>(
                  value: FavoritesSort.recentlySaved,
                  child: Text(l10n.favorites_sort_recently_saved),
                ),
                DropdownMenuItem<FavoritesSort>(
                  value: FavoritesSort.priceDesc,
                  child: Text(l10n.favorites_sort_price_desc),
                ),
                DropdownMenuItem<FavoritesSort>(
                  value: FavoritesSort.priceAsc,
                  child: Text(l10n.favorites_sort_price_asc),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  context.read<FavoritesPageBloc>().add(
                    FavoritesPageSortChanged(value),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
