import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../settings/lite_mode.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
import '../../l10n/app_localizations.dart';
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
      // PERF-H2 — cap the decode resolution to the display size for feed/list
      // images (the `flat` placeholder) so a full-size (~1920px) JPEG is never
      // decoded into a small card slot (~8 MB bitmap per card → decode jank +
      // memory pressure on low-end devices like the Infinix Note 8). Full-screen
      // heroes / galleries (`skeleton` placeholder) keep full fidelity so pinch-
      // zoom stays crisp. Data saver (lite mode) tightens the cap and shrinks the
      // disk cache. LayoutBuilder yields the box width; memCacheWidth is in device
      // pixels. ValueListenable so flipping the toggle re-paints live.
      result = LayoutBuilder(
        builder: (context, constraints) {
          final capToDisplay =
              placeholderStyle == AppImagePlaceholder.flat &&
              constraints.maxWidth.isFinite &&
              constraints.maxWidth > 0;
          final int? displayWidth = capToDisplay
              ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                    .round()
              : null;
          return ValueListenableBuilder<bool>(
            valueListenable: LiteMode.notifier,
            builder: (context, lite, _) {
              final int? memCap = displayWidth != null
                  ? (lite && displayWidth > _liteCacheWidth
                        ? _liteCacheWidth
                        : displayWidth)
                  : (lite ? _liteCacheWidth : null);
              return CachedNetworkImage(
                imageUrl: url!,
                fit: fit,
                memCacheWidth: memCap,
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
              );
            },
          );
        },
      );
    }

    // The label describes what the image SHOWS. When there is nothing to show —
    // no url, or the fetch failed — say so instead. Every caller used to pass
    // "image unavailable" as the label outright, so a photograph that loaded
    // perfectly well still announced itself as missing to a screen reader
    // (found on the device, 2026-09-03). Deciding it here keeps the two cases
    // from drifting apart again.
    final hasImage = url != null && url!.isNotEmpty;
    final label = hasImage
        ? semanticLabel
        : AppLocalizations.of(context)?.image_unavailable;
    if (label != null) {
      result = Semantics(label: label, image: true, child: result);
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
