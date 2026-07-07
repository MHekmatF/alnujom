import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/reduce_motion.dart';

/// Phase 029 (Reels W4) — a single reel surface inside the fullscreen feed.
///
/// Renders the poster still (cheap [AppNetworkImage]) until the supplied
/// [controller] reports `isInitialized`, then cross-fades to the video sized to
/// cover the viewport (BoxFit.cover via a centered, clipped [FittedBox]). The
/// controller's lifecycle (create / init / play / dispose) is owned entirely by
/// the parent feed page — this widget only reflects it and rebuilds on its
/// notifications.
///
/// Tapping toggles mute via [onToggleMute] and briefly surfaces a mute/unmute
/// glyph (driven by [muteHintVisible] + [muted]).
class ReelPlayer extends StatefulWidget {
  const ReelPlayer({
    super.key,
    required this.controller,
    required this.posterUrl,
    required this.muted,
    required this.muteHintVisible,
    required this.posterSemanticLabel,
    required this.muteToggleSemanticLabel,
    required this.onToggleMute,
  });

  /// The shared controller for THIS reel index, or null when it's outside the
  /// live window (so only the poster shows).
  final VideoPlayerController? controller;
  final String? posterUrl;
  final bool muted;

  /// When true, the centered mute/unmute glyph is shown (the parent flips this
  /// to false after a short delay).
  final bool muteHintVisible;
  final String posterSemanticLabel;

  /// Announced by TalkBack for the full-screen tap-to-mute gesture surface.
  final String muteToggleSemanticLabel;
  final VoidCallback onToggleMute;

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerTick);
  }

  @override
  void didUpdateWidget(ReelPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerTick);
      widget.controller?.addListener(_onControllerTick);
    }
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // The controller is owned by the parent; only drop our listener here.
    widget.controller?.removeListener(_onControllerTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final controller = widget.controller;
    final ready = controller != null && controller.value.isInitialized;
    final reduce = reduceMotion(context);

    return Semantics(
      button: true,
      label: widget.muteToggleSemanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggleMute,
        child: ColoredBox(
          color: colors.scrim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster — always rendered beneath; the video fades in over it.
              if (widget.posterUrl != null)
                AppNetworkImage(
                  url: widget.posterUrl,
                  placeholderStyle: AppImagePlaceholder.flat,
                  semanticLabel: widget.posterSemanticLabel,
                ),
              if (ready)
                // A genuine 0->1 fade-in on first mount (AnimatedOpacity only
                // animates on a value change, so mounting at opacity 1 was a
                // hard cut). Honors reduced motion.
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: reduce ? Duration.zero : AppMotion.base,
                  curve: AppMotion.curve,
                  builder: (context, value, child) =>
                      Opacity(opacity: value, child: child),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              // Centered mute/unmute hint glyph — fades out shortly after a tap.
              Center(
                child: AnimatedOpacity(
                  opacity: widget.muteHintVisible ? 1 : 0,
                  duration: reduce ? Duration.zero : AppMotion.base,
                  curve: AppMotion.curve,
                  child: _MuteGlyph(muted: widget.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MuteGlyph extends StatelessWidget {
  const _MuteGlyph({required this.muted});

  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.photoOverlay,
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Icon(
          muted ? LucideIcons.volume_off : LucideIcons.volume_2,
          color: colors.onPhoto,
          size: AppSpacing.xxl,
        ),
      ),
    );
  }
}
