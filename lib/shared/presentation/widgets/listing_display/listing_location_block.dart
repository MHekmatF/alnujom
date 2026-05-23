import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../features/locations/domain/entities/area.dart';
import '../../../../features/locations/domain/entities/city.dart';
import '../../../../features/locations/domain/entities/governorate.dart';

/// Phase 12 Q8=A shared widget — governorate / city / area names joined with
/// " / " (Phase 8 convention). Optional `addressText` line below.
///
/// Constitution IX-clean: no Supabase imports. Accepts domain entities only.
class ListingLocationBlock extends StatelessWidget {
  const ListingLocationBlock({
    super.key,
    required this.governorate,
    required this.city,
    required this.area,
    this.addressText,
  });

  final Governorate governorate;
  final City city;
  final Area area;
  final String? addressText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    final joined = [
      governorate.localizedName(locale),
      city.localizedName(locale),
      area.localizedName(locale),
    ].join(' / ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                joined,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
        if (addressText != null && addressText!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.xl),
            child: Text(
              addressText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
