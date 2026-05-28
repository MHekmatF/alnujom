import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';

/// Phase 12 Q8=A shared widget — renders amenities as a `Wrap` of chips.
///
/// The Phase 10 `ListingDetails.amenities` is a `List<String>` (an array of
/// amenity keys) rather than the `Map<String,dynamic>` shape the contract
/// originally anticipated; we accept the actual entity shape verbatim.
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

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final key in amenities)
          Chip(
            label: Text(_humanize(key)),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
      ],
    );
  }

  /// Defensive humanizer for raw amenity keys (e.g. "swimming_pool" →
  /// "Swimming pool"). Phase 12 ships without a per-amenity localized label
  /// catalog (deferred to a future spec); the snake_case → sentence-case
  /// transformation keeps the chips readable in both locales until that
  /// catalog lands.
  String _humanize(String key) {
    if (key.isEmpty) return key;
    final spaced = key.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
