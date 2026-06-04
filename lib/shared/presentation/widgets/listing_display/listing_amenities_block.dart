import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 12 Q8=A shared widget — renders amenities as a `Wrap` of chips.
///
/// The Phase 10 `ListingDetails.amenities` is a `List<String>` (an array of
/// amenity keys) rather than the `Map<String,dynamic>` shape the contract
/// originally anticipated; we accept the actual entity shape verbatim.
///
/// Phase 25: amenity keys from the canonical catalog are rendered with their
/// localized (Arabic/English) label; unknown keys fall back to a humanized
/// form so the chips stay readable.
///
/// Constitution IX-clean: no Supabase imports. Accepts plain Dart types only.
class ListingAmenitiesBlock extends StatelessWidget {
  const ListingAmenitiesBlock({super.key, required this.amenities});

  /// Truthy amenity keys to render. Empty list collapses the widget.
  final List<String> amenities;

  @override
  Widget build(BuildContext context) {
    if (amenities.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final key in amenities)
          Chip(
            label: Text(_amenityLabel(key, l10n)),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
      ],
    );
  }

  /// Localized label for a canonical amenity key (mirrors the listing-form
  /// catalog in `step_details.dart`); unknown keys fall back to [_humanize].
  String _amenityLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'elevator':
        return l10n.amenityElevator;
      case 'balcony':
        return l10n.amenityBalcony;
      case 'swimming_pool':
        return l10n.amenitySwimmingPool;
      case 'garden':
        return l10n.amenityGarden;
      case 'security':
        return l10n.amenitySecurity;
      case 'generator':
        return l10n.amenityGenerator;
      case 'solar_panels':
        return l10n.amenitySolarPanels;
      case 'central_heating':
        return l10n.amenityCentralHeating;
      case 'air_conditioning':
        return l10n.amenityAirConditioning;
      case 'furnished_kitchen':
        return l10n.amenityFurnishedKitchen;
      default:
        return _humanize(key);
    }
  }

  /// Defensive humanizer for non-catalog amenity keys (e.g. "sea_view" →
  /// "Sea view").
  String _humanize(String key) {
    if (key.isEmpty) return key;
    final spaced = key.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
