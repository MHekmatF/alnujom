// lib/features/favorites/presentation/widgets/favorite_heart_button.dart
//
// Phase 17 Sub-Phase F (T031) — Reusable heart-toggle button shared across all
// four listing surfaces (home feed, search results, map preview, listing
// details). Per contract phase17-favorite-heart-toggle.md and R-118.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/favorites_cubit.dart';

/// Visual treatment for [FavoriteHeartButton].
enum FavoriteHeartStyle {
  /// Plain icon button (app bars, list rows, details body).
  plain,

  /// A white circular chip with a soft shadow, for placing over a photo
  /// (the hero listing card / gallery).
  onImage,
}

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
  const FavoriteHeartButton({
    super.key,
    required this.listingId,
    this.style = FavoriteHeartStyle.plain,
  });

  final String listingId;

  /// Visual treatment — plain icon button, or a white over-photo chip.
  final FavoriteHeartStyle style;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.favorite_toggle_failed)));
      },
      builder: (context, state) {
        final isFavorited = state.favoritedIds.contains(listingId);
        final l10n = AppLocalizations.of(context)!;
        final colors = AppColors.of(context);
        final tooltip = isFavorited
            ? l10n.favorite_unsave_label
            : l10n.favorite_heart_label;

        // Phase 25 (Claude Design) — a favorited heart fills with the warm
        // coral accent on every surface.
        if (style == FavoriteHeartStyle.onImage) {
          return _OnImageChip(
            isFavorited: isFavorited,
            tooltip: tooltip,
            onPressed: () => _onTap(context, state),
          );
        }

        return IconButton(
          icon: _HeartPop(
            favorited: isFavorited,
            child: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
              color: isFavorited ? colors.accent : null,
            ),
          ),
          tooltip: tooltip,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.favorite_sign_in_prompt)));
      context.push(AppRoutes.login);
      return;
    }

    // Authenticated branch: a light haptic tick, then the optimistic toggle.
    HapticFeedback.lightImpact();
    final wasFavorited = state.favoritedIds.contains(listingId);
    getIt<FavoritesCubit>().toggle(listingId);

    // On removal, offer a quick Undo (re-toggling re-adds). Saves are obvious
    // (the heart fills + pops), so they don't need a confirmation snackbar.
    if (wasFavorited) {
      final l10n = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.of(context)
        ..clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.favorite_removed_snackbar),
          action: SnackBarAction(
            label: l10n.action_undo,
            onPressed: () => getIt<FavoritesCubit>().toggle(listingId),
          ),
        ),
      );
    }
  }
}

/// A one-shot "pop" (1.0 → 1.3 → 1.0) played only when [favorited] transitions
/// false→true (a user save) — never on first mount or on un-favorite, and
/// skipped under reduced motion.
class _HeartPop extends StatefulWidget {
  const _HeartPop({required this.favorited, required this.child});

  final bool favorited;
  final Widget child;

  @override
  State<_HeartPop> createState() => _HeartPopState();
}

class _HeartPopState extends State<_HeartPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.0,
        end: 1.3,
      ).chain(CurveTween(curve: AppMotion.curve)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.3,
        end: 1.0,
      ).chain(CurveTween(curve: AppMotion.curve)),
      weight: 1,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(_HeartPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.favorited && !oldWidget.favorited && !reduceMotion(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// The white circular over-photo treatment (Claude `an-heart`): a soft-shadowed
/// white chip whose heart fills with the coral accent when saved. The white
/// chip is theme-independent since it sits on imagery.
class _OnImageChip extends StatelessWidget {
  const _OnImageChip({
    required this.isFavorited,
    required this.tooltip,
    required this.onPressed,
  });

  final bool isFavorited;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final elevation = AppElevation.of(context);
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: elevation.level1,
        ),
        child: Material(
          color: Colors.white.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: _HeartPop(
                favorited: isFavorited,
                child: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: AppSpacing.xl,
                  color: isFavorited ? colors.accent : Colors.black54,
                  semanticLabel: tooltip,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
