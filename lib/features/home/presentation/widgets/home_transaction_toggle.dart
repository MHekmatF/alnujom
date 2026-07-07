import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../../search/domain/entities/filter_state.dart';

/// Phase 035 — the design's transaction-mode segmented control on Home
/// (للبيع · للإيجار · يومي). Each segment is a quick entry into Search
/// pre-filtered by that [ListingPurpose] (via `GoRouterState.extra`, the same
/// mechanism the property-type chips use). Purely a navigation shortcut — no
/// persistent selection on Home.
class HomeTransactionToggle extends StatelessWidget {
  const HomeTransactionToggle({super.key});

  static const _purposes = <ListingPurpose>[
    ListingPurpose.sale,
    ListingPurpose.rent,
    ListingPurpose.dailyRent,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: appRadius(AppRadii.pill),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _purposes.length; i++)
              Expanded(
                child: _Segment(
                  label: _label(l10n, _purposes[i]),
                  // The first segment (للبيع) reads as the primary/default deal
                  // type; all three are tappable shortcuts.
                  emphasized: i == 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go(
                      AppRoutes.search,
                      extra: FilterState(purpose: _purposes[i]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n, ListingPurpose p) => switch (p) {
    ListingPurpose.sale => l10n.listingPurposeSale,
    ListingPurpose.rent => l10n.listingPurposeRent,
    ListingPurpose.dailyRent => l10n.listingPurposeDailyRent,
    ListingPurpose.investment => l10n.listingPurposeInvestment,
  };
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.emphasized,
    required this.onTap,
  });

  final String label;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return PressScale(
      child: Material(
        color: emphasized ? colors.primary : Colors.transparent,
        borderRadius: appRadius(AppRadii.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kAppMinTouchTarget),
            child: Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: styles.labelLarge.copyWith(
                    color: emphasized
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
