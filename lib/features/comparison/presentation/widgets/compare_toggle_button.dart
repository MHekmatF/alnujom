// lib/features/comparison/presentation/widgets/compare_toggle_button.dart
//
// Over-photo compare affordance for a FavoriteCard: a small frosted scale-icon
// button that toggles this listing into/out of the shared ComparisonCubit.
// Selected → solid primary fill; unselected → dark glass. When the selection is
// already full (3) and this listing isn't in it, the button reads as disabled.
//
// Token-only styling; RTL-safe (PositionedDirectional placement is the caller's
// job). Reads the singleton ComparisonCubit from the widget tree.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/comparison_item.dart';
import '../cubit/comparison_cubit.dart';

/// A round compare toggle to drop over a card's photo (alongside the heart).
class CompareToggleButton extends StatelessWidget {
  const CompareToggleButton({super.key, required this.item});

  /// The listing snapshot this button toggles.
  final ComparisonItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final elevation = AppElevation.of(context);

    return BlocBuilder<ComparisonCubit, ComparisonState>(
      buildWhen: (a, b) =>
          a.contains(item.id) != b.contains(item.id) ||
          (a.count >= ComparisonCubit.maxItems) !=
              (b.count >= ComparisonCubit.maxItems),
      builder: (context, state) {
        final cubit = context.read<ComparisonCubit>();
        final selected = state.contains(item.id);
        // Full + not-already-selected → adding is blocked; dim the affordance.
        final blocked = !selected && state.count >= ComparisonCubit.maxItems;

        final fg = selected ? colors.onPrimary : colors.onPhoto;
        final fill = selected ? colors.primary : colors.photoOverlay;

        return Opacity(
          opacity: blocked ? 0.45 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: appRadius(AppRadii.pill),
              boxShadow: elevation.level1,
            ),
            child: ClipRRect(
              borderRadius: appRadius(AppRadii.pill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Material(
                  color: fill,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: blocked
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            cubit.toggle(item);
                          },
                    child: Tooltip(
                      message: selected
                          ? l10n.comparisonRemoveFromCompare
                          : (blocked
                                ? l10n.comparisonMaxReached
                                : l10n.comparisonAddToCompare),
                      child: SizedBox(
                        width: kAppMinTouchTarget,
                        height: kAppMinTouchTarget,
                        child: Icon(
                          selected ? LucideIcons.check : LucideIcons.scale,
                          size: AppSpacing.lg,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
