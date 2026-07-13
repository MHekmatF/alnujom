import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../../listing_form/domain/entities/listing.dart';

/// The listing-detail key-facts strip, rebuilt to the DC "Blue Crown" design
/// (`AlNujom.dc.html` §DETAIL): a single `surface2` rounded strip of equal-width
/// columns, each a primary icon over a combined value string ("4 غرف",
/// "3 حمّامات", "220 م²", "الطابق 7"). Renders only the facts that are present
/// (land has no rooms/baths/floor) and collapses to nothing when none apply.
class ListingFactsBlock extends StatelessWidget {
  const ListingFactsBlock({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final facts = <(IconData, String)>[
      if (listing.rooms != null)
        (
          Icons.king_bed,
          '${formatLocalizedNumber(listing.rooms!, locale)} '
              '${l10n.spec_rooms_label}',
        ),
      if (listing.bathrooms != null)
        (
          Icons.bathtub,
          '${formatLocalizedNumber(listing.bathrooms!, locale)} '
              '${l10n.spec_baths_label}',
        ),
      if (listing.areaSize != null)
        (
          Icons.square_foot,
          '${_formatArea(locale, listing.areaSize!)} ${l10n.spec_area_unit}',
        ),
      if (listing.floor != null)
        (
          Icons.stairs,
          '${l10n.spec_floor_label} '
              '${formatLocalizedNumber(listing.floor!, locale)}',
        ),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.card),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (final (icon, value) in facts)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 23, color: colors.primary),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _formatArea(Locale locale, double value) {
    if (value == value.roundToDouble()) {
      return formatLocalizedNumber(value.round(), locale);
    }
    return formatLocalizedNumber(
      double.parse(value.toStringAsFixed(1)),
      locale,
    );
  }
}
