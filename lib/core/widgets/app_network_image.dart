import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../settings/lite_mode.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
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

  /// Cap (logical-ish px) applied to decode + disk cache when Data saver is on.
  static const int _liteCacheWidth = 600;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Honour "Remove animations": when reduced motion is on, the image and its
    // placeholder snap in instantly (no cross-fade).
    final reduce = reduceMotion(context);
    final fade = reduce ? Duration.zero : AppMotion.base;

    Widget result;
    if (url == null || url!.isEmpty) {
      result = _fallback(colors, Icons.apartment_rounded);
    } else {
      // Data saver (lite mode): when ON, decode/fetch at a reduced resolution so
      // less data is pulled over the wire and less memory is spent decoding.
      // When OFF, render at full fidelity exactly as before. ValueListenable so
      // flipping the toggle re-paints live without a route rebuild.
      result = ValueListenableBuilder<bool>(
        valueListenable: LiteMode.notifier,
        builder: (context, lite, _) => CachedNetworkImage(
          imageUrl: url!,
          fit: fit,
          // ~600px is enough for feed cards / most heroes on phones while
          // roughly halving the bytes fetched on a slow connection.
          memCacheWidth: lite ? _liteCacheWidth : null,
          maxWidthDiskCache: lite ? _liteCacheWidth : null,
          fadeInDuration: fade,
          fadeInCurve: AppMotion.curve,
          placeholderFadeInDuration: fade,
          placeholder: (context, _) =>
              placeholderStyle == AppImagePlaceholder.skeleton
              ? const LoadingState.card()
              : ColoredBox(color: colors.surfaceVariant),
          errorWidget: (context, _, __) =>
              _fallback(colors, Icons.apartment_rounded),
        ),
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

  // A branded "no photo yet" placeholder — a soft tonal gradient with a muted
  // property glyph — so photo-less or failed listings read as intentional
  // rather than broken (real-estate feeds live on imagery).
  Widget _fallback(AppColors colors, IconData icon) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [
          colors.surfaceVariant,
          Color.alphaBlend(colors.primary.withAlpha(0x1F), colors.card),
        ],
      ),
    ),
    child: Center(
      child: Icon(
        icon,
        color: colors.primary.withAlpha(0x7A),
        size: AppSpacing.xxxl,
      ),
    ),
  );
}
