import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../../search/domain/entities/filter_state.dart';

/// Premium uplift — similar-listings empty recovery.
///
/// When [SimilarListingsCubit] finishes with an EMPTY pool the carousel would
/// otherwise collapse to nothing, leaving a dead end. Instead this small card
/// invites the user to keep browsing: an outlined "Browse similar in this area"
/// button that pushes the search route seeded with the source listing's
/// governorate + property type (so they land on a relevant result set).
///
/// Token-only; RTL-safe via [EdgeInsetsDirectional]. Renders inside the same
/// section padding the carousel header uses, so it sits flush with the page.
class SimilarListingsEmpty extends StatelessWidget {
  const SimilarListingsEmpty({
    super.key,
    required this.propertyType,
    this.governorateId,
  });

  /// Source listing's property type — seeds the search filter.
  final PropertyType propertyType;

  /// Source listing's governorate id (null → property-type pool only).
  final String? governorateId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: appRadius(AppRadii.lg),
          border: Border.all(color: colors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.compass,
                  size: AppSpacing.xl,
                  color: colors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.listing_details_similar_empty_title,
                    style: styles.titleMedium.copyWith(color: colors.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => _browse(context),
                icon: const Icon(LucideIcons.search),
                label: Text(l10n.listing_details_similar_empty_action),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _browse(BuildContext context) {
    context.push(
      AppRoutes.search,
      extra: FilterState(
        propertyType: propertyType,
        governorateId: governorateId,
      ),
    );
  }
}
