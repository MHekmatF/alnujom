import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/rating_stars.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/seller_trust_cubit.dart';

/// Compact seller-trust summary for the contact card: the seller's rating stars
/// + "(N)" review count when a rating exists, and a responsiveness badge
/// ("Responds to {pct}% of inquiries" / "Usually responds within ~{h}h") when
/// the response stats are meaningful (total > 0).
///
/// Reads the page-provided [SellerTrustCubit]. Collapses to nothing when there's
/// no data — never adds empty chrome to the contact card.
class SellerTrustSummary extends StatelessWidget {
  const SellerTrustSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SellerTrustCubit, SellerTrustState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.rating != curr.rating ||
          prev.stats != curr.stats,
      builder: (context, state) {
        if (state.status != SellerTrustStatus.loaded) {
          return const SizedBox.shrink();
        }

        final showRating = state.hasRating;
        final showResponse = state.hasResponseSignal;
        if (!showRating && !showResponse) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context)!;
        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);

        final children = <Widget>[];

        if (showRating) {
          children.add(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RatingStars(value: state.rating!.avgRating, size: AppSpacing.md),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.reviews_rating_with_count(
                    state.rating!.avgRating,
                    state.rating!.reviewCount,
                  ),
                  style: styles.labelMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          );
        }

        if (showResponse) {
          final badge = _responseBadge(context, l10n, state);
          if (badge != null) children.add(badge);
        }

        if (children.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        );
      },
    );
  }

  /// Builds the responsiveness badge. Prefers the rate ("Responds to X%"); when
  /// the rate is absent but an average hour figure exists, shows the latency
  /// ("Usually responds within ~Hh"). Null when neither is meaningful.
  Widget? _responseBadge(
    BuildContext context,
    AppLocalizations l10n,
    SellerTrustState state,
  ) {
    final stats = state.stats!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    String? text;
    if (stats.responseRate != null) {
      final pct = (stats.responseRate! * 100).round();
      text = l10n.reviews_response_rate(pct);
    } else if (stats.avgResponseHours != null) {
      text = l10n.reviews_response_hours(stats.avgResponseHours!.round());
    }
    if (text == null) return null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_outlined,
              size: AppSpacing.md,
              color: colors.success,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                text,
                style: styles.labelMedium.copyWith(color: colors.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
