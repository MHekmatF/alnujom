import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/gradients.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../domain/entities/recently_viewed_listing.dart';

/// A fixed-width compact card for the Home "recently viewed" carousel. Reuses
/// the property-card visual language (photo-forward hero, then a body with a
/// prominent price, title and location) at a narrower footprint so several fit
/// in a horizontal scroller. Tapping routes to that listing's detail page.
///
/// Token-only styling. RTL-safe; the price renders LTR with the active locale's
/// numerals. The snapshot may be stale — tapping always re-fetches the live
/// listing on the details page.
class RecentlyViewedCard extends StatelessWidget {
  const RecentlyViewedCard({
    super.key,
    required this.item,
    required this.width,
  });

  final RecentlyViewedListing item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    final location = item.governorateName?.trim() ?? '';

    return PressScale(
      child: SizedBox(
        width: width,
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: appRadius(AppRadii.lg),
            border: Border.all(color: colors.outline),
            boxShadow: elevation.level2,
          ),
          child: ClipRRect(
            borderRadius: appRadius(AppRadii.lg),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () =>
                    context.push(AppRoutes.listingDetailsFor(item.id)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(
                      imageUrl: item.mainImageUrl,
                      imageUnavailableLabel: l10n.image_unavailable,
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.priceAmount != null &&
                              item.currencyCode != null) ...[
                            Text(
                              l10n.priceWithCurrency(
                                _formatAmount(context, item.priceAmount!),
                                item.currencyCode!,
                              ),
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.start,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: styles.priceMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                          ],
                          Text(
                            item.title.isEmpty ? '—' : item.title,
                            style: styles.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.map_pin,
                                  size: AppSpacing.md,
                                  color: colors.textMuted,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: styles.labelMedium.copyWith(
                                      color: colors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Localized amount with the active locale's numerals (no fractional part —
  /// the snapshot only carries the primary amount string, not the full currency
  /// catalog). Falls back to the raw string if it doesn't parse as a number.
  String _formatAmount(BuildContext context, String amount) {
    final parsed = num.tryParse(amount);
    if (parsed == null) return amount;
    return formatLocalizedNumber(parsed.round(), Localizations.localeOf(context));
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.imageUrl, required this.imageUnavailableLabel});

  final String? imageUrl;
  final String imageUnavailableLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: AppNetworkImage(
            url: imageUrl,
            semanticLabel: imageUnavailableLabel,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.of(context).photoScrim,
            ),
          ),
        ),
      ],
    );
  }
}
