// lib/features/agency/presentation/widgets/publish_under_agency_field.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T053).
// Selector over "Personal account" + the user's active agencies whose status
// permits publishing ({pending, approved} via AgencyStatus.canPublishUnder).
// Renders nothing when the user has no eligible agency (no reflow for the
// common personal-only case). Phase 2 tokens only.
import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/agency.dart';

class PublishUnderAgencyField extends StatelessWidget {
  const PublishUnderAgencyField({
    super.key,
    required this.agencies,
    required this.selectedAgencyId,
    required this.onChanged,
  });

  /// The user's active agencies (already filtered to publishable statuses by
  /// the host bloc, but defensively re-filtered here).
  final List<Agency> agencies;

  /// Currently-selected agency id, or null for "Personal account".
  final String? selectedAgencyId;

  /// Called with the chosen agency id (null → personal).
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final eligible = agencies.where((a) => a.status.canPublishUnder).toList();

    // No eligible agency → no selector at all (publishing stays personal).
    if (eligible.isEmpty) return const SizedBox.shrink();

    // Guard against a stale selection that is no longer eligible.
    final validSelection = eligible.any((a) => a.id == selectedAgencyId)
        ? selectedAgencyId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        // Batch-2 restyle: the bare OutlineInputBorder dropdown + a raw
        // `textTheme.titleSmall` caption became the shared AppDropdown, which
        // carries the DS filled fill, focus ring, caret and rounded popup and
        // renders its own floating label.
        AppDropdown<String?>(
          label: l10n.listing_publish_under_agency_label,
          value: validSelection,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.listing_publish_personal_option),
            ),
            for (final agency in eligible)
              DropdownMenuItem<String?>(
                value: agency.id,
                child: Text(
                  agency.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
