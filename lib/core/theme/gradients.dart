import 'package:flutter/material.dart';

import 'colors.dart';

/// Phase 25 premium uplift — gradient tokens.
///
/// Tasteful, restrained gradients only (DESIGN.md anti-patterns: no purple,
/// no glassmorphism overload). Every gradient is **derived from existing color
/// tokens** ([AppColors]) rather than raw literals, so it stays theme-aware and
/// token-clean. Consume via `AppGradients.of(context)`.
@immutable
final class AppGradients {
  const AppGradients._({
    required this.photoScrim,
    required this.photoTopScrim,
    required this.featuredTint,
    required this.screenBackground,
    required this.primaryGradient,
  });

  factory AppGradients.of(BuildContext context) {
    final colors = AppColors.of(context);
    final overlay = colors.photoOverlay;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppGradients._(
      // Design #8 "Glass / Depth" — the soft indigo-tinted background wash that
      // the whole app floats over; a hint of primary at the top easing into the
      // flat surface, so cards read as lifted.
      screenBackground: LinearGradient(
        begin: AlignmentDirectional.topCenter,
        end: AlignmentDirectional.bottomCenter,
        colors: <Color>[
          Color.lerp(colors.primary, colors.surface, isDark ? 0.88 : 0.90)!,
          colors.surface,
        ],
        stops: const <double>[0.0, 0.5],
      ),
      // Indigo action gradient for primary buttons / active chips / the filter
      // FAB (a lighter top-start easing to a deeper bottom-end).
      primaryGradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: <Color>[
          Color.lerp(colors.primary, Colors.white, 0.16)!,
          colors.primary,
          Color.lerp(colors.primary, Colors.black, 0.12)!,
        ],
      ),
      // Bottom-anchored scrim so over-photo text/pills stay legible on bright
      // imagery. Transparent for the top ~half, easing into the overlay.
      photoScrim: LinearGradient(
        begin: AlignmentDirectional.topCenter,
        end: AlignmentDirectional.bottomCenter,
        colors: <Color>[overlay.withValues(alpha: 0), overlay],
        stops: const <double>[0.45, 1.0],
      ),
      // Lighter top scrim so a top-corner favorite chip / featured badge keeps
      // contrast against a light sky in the photo.
      photoTopScrim: LinearGradient(
        begin: AlignmentDirectional.topCenter,
        end: AlignmentDirectional.bottomCenter,
        colors: <Color>[
          overlay.withValues(alpha: 0.42),
          overlay.withValues(alpha: 0),
        ],
        stops: const <double>[0.0, 0.55],
      ),
      // Whisper-soft brand tint for featured/premium surfaces — a barely-there
      // primary wash, never a loud gradient.
      featuredTint: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: <Color>[
          colors.primary.withValues(alpha: 0.06),
          colors.primary.withValues(alpha: 0),
        ],
      ),
    );
  }

  /// Bottom→transparent dark scrim for legibility of over-photo content.
  final Gradient photoScrim;

  /// Top→transparent dark scrim for top-corner over-photo affordances.
  final Gradient photoTopScrim;

  /// Subtle diagonal brand wash for featured/premium cards.
  final Gradient featuredTint;

  /// Design #8 — the soft indigo-tinted page background the app floats over.
  final Gradient screenBackground;

  /// Indigo action gradient for primary buttons / active chips / FABs.
  final Gradient primaryGradient;
}
