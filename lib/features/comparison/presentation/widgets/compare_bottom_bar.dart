// lib/features/comparison/presentation/widgets/compare_bottom_bar.dart
//
// The "Compare (N)" action bar that slides up over the FavoritesPage once two
// or more listings are selected. Tapping it opens the ComparisonPage (a plain
// MaterialPageRoute — no new go_router route — re-providing the shared singleton
// cubit via BlocProvider.value). A secondary "clear" action empties the set.
//
// Token-only styling; RTL-safe. Reads the singleton ComparisonCubit from the
// tree (the page wraps its body in a BlocProvider.value).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/comparison_cubit.dart';
import '../pages/comparison_page.dart';

/// A bottom-anchored "Compare (N)" bar. Renders nothing until at least two
/// listings are selected, then animates in.
class CompareBottomBar extends StatelessWidget {
  const CompareBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final reduce = reduceMotion(context);

    return BlocBuilder<ComparisonCubit, ComparisonState>(
      buildWhen: (a, b) => a.canCompare != b.canCompare || a.count != b.count,
      builder: (context, state) {
        final visible = state.canCompare;

        final bar = !visible
            ? const SizedBox.shrink()
            : SafeArea(
                top: false,
                minimum: const EdgeInsets.all(AppSpacing.lg),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: appRadius(AppRadii.lg),
                    boxShadow: elevation.level2,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: appRadius(AppRadii.lg),
                      onTap: () => _openComparison(context),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.scale,
                              size: AppSpacing.lg,
                              color: colors.onPrimary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.comparisonCompareCount(state.count),
                                style: styles.labelLarge.copyWith(
                                  color: colors.onPrimary,
                                ),
                              ),
                            ),
                            // Inline clear (keeps the primary tap = "compare").
                            // Full 48dp hit area + label so the target clears
                            // the touch minimum next to the large primary tap.
                            InkResponse(
                              radius: kAppMinTouchTarget / 2,
                              onTap: () =>
                                  context.read<ComparisonCubit>().clear(),
                              child: Tooltip(
                                message: l10n.comparisonClearAll,
                                child: SizedBox.square(
                                  dimension: kAppMinTouchTarget,
                                  child: Icon(
                                    LucideIcons.x,
                                    size: AppSpacing.lg,
                                    color: colors.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

        return AnimatedSwitcher(
          duration: reduce ? Duration.zero : AppMotion.base,
          switchInCurve: AppMotion.emphasized,
          switchOutCurve: AppMotion.exit,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: bar,
        );
      },
    );
  }

  void _openComparison(BuildContext context) {
    // Re-provide the SAME singleton cubit to the pushed page so the comparison
    // view stays in lock-step with the selection (no new go_router route).
    final cubit = context.read<ComparisonCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<ComparisonCubit>.value(
          value: cubit,
          child: const ComparisonPage(),
        ),
      ),
    );
  }
}
