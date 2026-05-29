import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../features/favorites/presentation/bloc/favorites_cubit.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 13 (spec/013-home-and-details) — Per-listing action block.
///
/// Favorite CTA rewired in Phase 17 (spec/017-favorites) to a live
/// `BlocSelector`-driven toggle with the anonymous-aware `FavoritesCubit`
/// branch. Share + Report stay as Q2=A Coming-soon stubs (FR-033).
///
/// Future phases:
/// - Share: `share_plus` introduced at share-wiring phase (NOT Phase 13 —
///   FR-033 explicitly excludes share_plus from Phase 13 pubspec).
/// - Report: inquiry / reports phase wires report submission.
class PerListingActionBlock extends StatelessWidget {
  const PerListingActionBlock({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Favorite CTA — Phase 17 live toggle (Share + Report unchanged).
        BlocSelector<FavoritesCubit, FavoritesState, bool>(
          bloc: getIt<FavoritesCubit>(),
          selector: (s) => s.favoritedIds.contains(listingId),
          builder: (context, isFavorited) {
            return _ActionButton(
              icon: isFavorited ? Icons.favorite : Icons.favorite_border,
              label: isFavorited
                  ? l10n.favorite_unsave_label
                  : l10n.favorite_heart_label,
              onPressed: () => _onFavoriteTap(context),
            );
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        // Share CTA — Q2=A stub (FR-033)
        _ActionButton(
          icon: Icons.share_outlined,
          label: l10n.cta_share,
          onPressed: () =>
              _showComingSoon(context, l10n.action_share_coming_soon),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Report CTA — Q2=A stub (FR-033)
        _ActionButton(
          icon: Icons.flag_outlined,
          label: l10n.cta_report,
          onPressed: () =>
              _showComingSoon(context, l10n.action_report_coming_soon),
        ),
      ],
    );
  }

  /// Mirrors `FavoriteHeartButton._onTap` — anonymous branch shows prompt +
  /// routes to login; authenticated branch toggles via the shared singleton.
  void _onFavoriteTap(BuildContext context) {
    final cubit = getIt<FavoritesCubit>();
    if (!cubit.state.isSignedIn) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.favorite_sign_in_prompt)));
      context.push(AppRoutes.login);
      return;
    }
    cubit.toggle(listingId);
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
