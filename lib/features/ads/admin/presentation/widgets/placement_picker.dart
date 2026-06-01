// Phase 21 (spec/021-ads-banners) — T024
// PlacementPicker: multi-select of AdPlacement + per-placement priority int.
// Flags categoryBanner as "not yet live" per R-175.
// Phase 2 tokens only; RTL-safe.
// Constitution IX: zero supabase_flutter imports.
import 'package:flutter/material.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/ad_placement.dart';
import '../../../domain/entities/ad_placement_assignment.dart';

/// Multi-select widget for ad placements.
///
/// Each selected placement also requires a priority integer (higher = shown
/// first in the carousel). [categoryBanner] is selectable but visibly flagged
/// "not yet live" per R-175.
///
/// Emits the updated list via [onChanged] whenever the selection or a priority
/// value changes.
class PlacementPicker extends StatefulWidget {
  const PlacementPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Currently selected placement assignments.
  final List<AdPlacementAssignment> value;

  /// Called whenever the selection or a priority changes.
  final ValueChanged<List<AdPlacementAssignment>> onChanged;

  @override
  State<PlacementPicker> createState() => _PlacementPickerState();
}

class _PlacementPickerState extends State<PlacementPicker> {
  late final Map<AdPlacement, TextEditingController> _priorityControllers;

  @override
  void initState() {
    super.initState();
    _priorityControllers = {
      for (final p in AdPlacement.values)
        p: TextEditingController(
          text: _priorityFor(p)?.toString() ?? '1',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _priorityControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int? _priorityFor(AdPlacement placement) {
    try {
      return widget.value
          .firstWhere((a) => a.placement == placement)
          .priority;
    } catch (_) {
      return null;
    }
  }

  bool _isSelected(AdPlacement placement) =>
      widget.value.any((a) => a.placement == placement);

  void _togglePlacement(AdPlacement placement, bool selected) {
    final updated = List<AdPlacementAssignment>.from(widget.value);
    if (selected) {
      final priorityText = _priorityControllers[placement]!.text.trim();
      final priority = int.tryParse(priorityText) ?? 1;
      updated.add(AdPlacementAssignment(placement: placement, priority: priority));
    } else {
      updated.removeWhere((a) => a.placement == placement);
    }
    widget.onChanged(updated);
  }

  void _updatePriority(AdPlacement placement, String text) {
    if (!_isSelected(placement)) return;
    final priority = int.tryParse(text.trim()) ?? 1;
    final updated = widget.value.map((a) {
      if (a.placement == placement) {
        return AdPlacementAssignment(placement: placement, priority: priority);
      }
      return a;
    }).toList();
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adsAdminPlacementsLabel,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...AdPlacement.values.map((placement) {
          final selected = _isSelected(placement);
          final isNotYetLive = placement == AdPlacement.categoryBanner;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (v) => _togglePlacement(placement, v ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _placementLabel(l10n, placement),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (isNotYetLive)
                        Text(
                          l10n.adPlacementCategoryBannerNotYetLive,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 64,
                    child: TextFormField(
                      controller: _priorityControllers[placement],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.adsAdminPriorityLabel,
                        isDense: true,
                      ),
                      onChanged: (v) => _updatePriority(placement, v),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  String _placementLabel(AppLocalizations l10n, AdPlacement placement) {
    return switch (placement) {
      AdPlacement.homeTopBanner => l10n.adPlacementHomeTopBanner,
      AdPlacement.homeMiddleBanner => l10n.adPlacementHomeMiddleBanner,
      AdPlacement.searchResultsBanner => l10n.adPlacementSearchResultsBanner,
      AdPlacement.listingDetailsBanner => l10n.adPlacementListingDetailsBanner,
      AdPlacement.categoryBanner => l10n.adPlacementCategoryBanner,
    };
  }
}
