// lib/features/favorites/presentation/widgets/favorite_heart_button.dart
//
// Phase 17 Sub-Phase F (T031) — Reusable heart-toggle button shared across all
// four listing surfaces (home feed, search results, map preview, listing
// details). Per contract phase17-favorite-heart-toggle.md and R-118.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/favorites_cubit.dart';

/// A filled/outlined heart icon that reflects the current favorite state for
/// [listingId] and handles the authenticated toggle + anonymous sign-in prompt.
///
/// Uses `BlocConsumer` — the `buildWhen` limits rebuilds to changes in the
/// favorited status for this specific listing (FR-005 / R-110), while
/// `listenWhen` catches the `lastToggleFailed` flag to show the error snackbar
/// without triggering an extra rebuild (FR-006).
///
/// Tokens only — no inline hex, font-size, or padding (FR-029).
class FavoriteHeartButton extends StatelessWidget {
  const FavoriteHeartButton({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FavoritesCubit, FavoritesState>(
      // The cubit is a GetIt @lazySingleton, not provided in the widget tree —
      // pass it explicitly so this button works on every surface (home/search/
      // map/details/favorites page) without requiring a BlocProvider ancestor
      // (mirrors Phase 16 InquiriesAppBarAction).
      bloc: getIt<FavoritesCubit>(),
      // Only rebuild when the favorite state for THIS listing changes.
      buildWhen: (previous, current) =>
          previous.favoritedIds.contains(listingId) !=
              current.favoritedIds.contains(listingId) ||
          previous.isSignedIn != current.isSignedIn,
      // Listen for toggle failures to show the snackbar (FR-006).
      listenWhen: (previous, current) =>
          current.lastToggleFailed && !previous.lastToggleFailed,
      listener: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.favorite_toggle_failed)),
        );
      },
      builder: (context, state) {
        final isFavorited = state.favoritedIds.contains(listingId);
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;

        return IconButton(
          icon: Icon(
            isFavorited ? Icons.favorite : Icons.favorite_border,
            color: isFavorited ? scheme.error : null,
          ),
          tooltip: isFavorited
              ? l10n.favorite_unsave_label
              : l10n.favorite_heart_label,
          onPressed: () => _onTap(context, state),
        );
      },
    );
  }

  void _onTap(BuildContext context, FavoritesState state) {
    // Anonymous branch: prompt sign-in, do NOT toggle, do NOT pre-auth save
    // (Q2=A / FR-008 / FR-009 / R-116).
    if (!state.isSignedIn) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.favorite_sign_in_prompt)),
      );
      context.push(AppRoutes.login);
      return;
    }

    // Authenticated branch: optimistic toggle via the shared singleton.
    getIt<FavoritesCubit>().toggle(listingId);
  }
}
