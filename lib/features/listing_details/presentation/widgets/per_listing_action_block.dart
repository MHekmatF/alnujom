import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 13 (spec/013-home-and-details) — Per-listing action block.
///
/// Three Q2=A stub CTAs (Favorite / Share / Report). All taps show a
/// floating Coming-soon snackbar; NO share-sheet / favorites mutation /
/// report INSERT per Q2=A + contracts/phase13-cta-stub-treatment.md.
///
/// Future phases:
/// - Favorites: dedicated phase wires favorite mutation + auth-required Q3=A.
/// - Share: `share_plus` introduced at share-wiring phase (NOT Phase 13 —
///   FR-033 explicitly excludes share_plus from Phase 13 pubspec).
/// - Report: inquiry / reports phase wires report submission.
class PerListingActionBlock extends StatelessWidget {
  const PerListingActionBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Favorite CTA
        _ActionButton(
          icon: Icons.favorite_border,
          label: l10n.cta_favorite,
          onPressed: () =>
              _showComingSoon(context, l10n.action_favorite_coming_soon),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Share CTA
        _ActionButton(
          icon: Icons.share_outlined,
          label: l10n.cta_share,
          onPressed: () =>
              _showComingSoon(context, l10n.action_share_coming_soon),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Report CTA
        _ActionButton(
          icon: Icons.flag_outlined,
          label: l10n.cta_report,
          onPressed: () =>
              _showComingSoon(context, l10n.action_report_coming_soon),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: theme.textTheme.labelMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
