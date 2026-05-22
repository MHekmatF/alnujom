import 'package:flutter/material.dart';

import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

class StepMediaPlaceholder extends StatelessWidget {
  const StepMediaPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.listingFormMediaPlaceholderBanner,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
