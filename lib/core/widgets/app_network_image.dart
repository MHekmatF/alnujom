import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/motion.dart';
import 'loading_state.dart';
import 'reduce_motion.dart';

/// Placeholder strategy while a network image loads.
///
/// - [flat] — a cheap [ColoredBox] (no ticker). Use in feeds/lists where many
///   instances are alive at once (kind to low-end GPUs).
/// - [skeleton] — the animated shimmer [LoadingState]. Reserve for full-screen
///   heroes / galleries where a single instance is visible.
enum AppImagePlaceholder { flat, skeleton }

/// The app's single network-image widget: a [CachedNetworkImage] that always
/// fades in ([AppMotion.base]) over a token placeholder, shows a token error
/// glyph on failure, and can optionally own a [Hero] flight.
///
/// Callers clip/shape it themselves (e.g. `ClipRRect`) — this widget never
/// rounds or sizes itself, so it drops into existing layouts unchanged.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderStyle = AppImagePlaceholder.flat,
    this.heroTag,
    this.semanticLabel,
  });

  final String? url;
  final BoxFit fit;
  final AppImagePlaceholder placeholderStyle;
  final Object? heroTag;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Honour "Remove animations": when reduced motion is on, the image and its
    // placeholder snap in instantly (no cross-fade).
    final reduce = reduceMotion(context);
    final fade = reduce ? Duration.zero : AppMotion.base;

    Widget result;
    if (url == null || url!.isEmpty) {
      result = _fallback(colors, Icons.image_not_supported_outlined);
    } else {
      result = CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        fadeInDuration: fade,
        fadeInCurve: AppMotion.curve,
        placeholderFadeInDuration: fade,
        placeholder: (context, _) => placeholderStyle == AppImagePlaceholder.skeleton
            ? const LoadingState.card()
            : ColoredBox(color: colors.surfaceVariant),
        errorWidget: (context, _, __) =>
            _fallback(colors, Icons.broken_image_outlined),
      );
    }

    if (semanticLabel != null) {
      result = Semantics(label: semanticLabel, image: true, child: result);
    }
    if (heroTag != null) {
      result = Hero(tag: heroTag!, child: result);
    }
    return result;
  }

  Widget _fallback(AppColors colors, IconData icon) => ColoredBox(
    color: colors.surfaceVariant,
    child: Center(child: Icon(icon, color: colors.onSurfaceVariant)),
  );
}
