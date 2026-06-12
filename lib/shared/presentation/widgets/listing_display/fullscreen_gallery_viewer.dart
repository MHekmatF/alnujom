import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/glass_pill.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../features/listing_details/data/listing_details_video_launcher.dart';
import '../../../../features/listing_details/presentation/pages/panorama_tour_page.dart';
import '../../../../features/listing_form/domain/entities/listing_media.dart';
import '../../../../l10n/app_localizations.dart';

/// One entry in the fullscreen viewer: the original [ListingMedia] row plus
/// its already-resolved public image URL (null for videos / unresolvable
/// rows). URLs are resolved by the caller ([ListingGallery] — the one shared
/// widget holding the documented Constitution-IX storage exception) so this
/// page imports zero `package:supabase_flutter`.
class FullscreenGalleryItem {
  const FullscreenGalleryItem({required this.media, this.imageUrl});

  final ListingMedia media;
  final String? imageUrl;
}

/// Phase 28 — story-style fullscreen media viewer.
///
/// An immersive scrim-backed [PageView] over the listing's media, opened from
/// the inline [ListingGallery] at the tapped index:
///
/// * images pinch-zoom in an [InteractiveViewer] (max ~4x);
/// * video rows keep the inline gallery's play affordance and launch in the
///   OS player via [ListingDetailsVideoLauncher] on tap;
/// * panorama rows badge the existing 360° pill and open [PanoramaTourPage];
/// * a [GlassPill] counter tracks `{current} of {total}`;
/// * vertical drag-to-dismiss translates the pager and fades the barrier,
///   popping past the release threshold.
///
/// Pushed via [open]'s fade + slight-scale [PageRouteBuilder] (instant under
/// reduce-motion). Deliberately NO [Hero]: the details page already wraps the
/// inline gallery in a page-level Hero and nested Heroes assert.
class FullscreenGalleryViewer extends StatefulWidget {
  const FullscreenGalleryViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  final List<FullscreenGalleryItem> items;
  final int initialIndex;

  /// Pushes the viewer over the current route with a fade + slight-scale
  /// transition. The route is non-opaque so the drag-to-dismiss barrier fade
  /// reveals the page beneath (story-style); `opaque: true` would drop the
  /// underlying route subtree and the fade would reveal a black void.
  static Future<void> open(
    BuildContext context, {
    required List<FullscreenGalleryItem> items,
    int initialIndex = 0,
  }) {
    final reduced = reduceMotion(context);
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: null,
        transitionDuration: reduced ? Duration.zero : AppMotion.slow,
        reverseTransitionDuration: reduced ? Duration.zero : AppMotion.base,
        pageBuilder: (_, __, ___) =>
            FullscreenGalleryViewer(items: items, initialIndex: initialIndex),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (reduceMotion(context)) return child;
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.emphasized,
            reverseCurve: AppMotion.exit,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<FullscreenGalleryViewer> createState() =>
      _FullscreenGalleryViewerState();
}

class _FullscreenGalleryViewerState extends State<FullscreenGalleryViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _current = widget.initialIndex;

  /// Cumulative vertical drag displacement (signed; up or down dismisses).
  double _dragOffset = 0;
  bool _dragging = false;

  /// True while the visible image page is pinch-zoomed in: paging and the
  /// dismiss drag are suspended so the [InteractiveViewer] owns panning.
  bool _zoomed = false;

  /// Drag distance past which release dismisses the viewer.
  static const double _dismissDistance = 120;

  /// Fling velocity (px/s) past which release dismisses regardless of
  /// distance.
  static const double _dismissVelocity = 700;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset.abs() > _dismissDistance ||
        velocity.abs() > _dismissVelocity) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _dragging = false;
      _dragOffset = 0;
    });
  }

  void _onDragCancel() {
    setState(() {
      _dragging = false;
      _dragOffset = 0;
    });
  }

  void _onZoomChanged(bool zoomed) {
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.sizeOf(context).height;
    // 0 → resting, 1 → fully dragged toward dismissal (barrier ~gone).
    final dragFraction = (_dragOffset.abs() / (_dismissDistance * 2)).clamp(
      0.0,
      1.0,
    );
    // Implicit animations track the finger instantly mid-drag and ease back
    // on release; reduce-motion collapses the snap-back to an instant jump.
    final snapDuration = _dragging || reduceMotion(context)
        ? Duration.zero
        : AppMotion.fast;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Story-style barrier — a full-strength scrim that thins out as the
          // user drags toward dismissal, revealing the page beneath.
          AnimatedOpacity(
            opacity: 1.0 - (0.7 * dragFraction),
            duration: snapDuration,
            curve: AppMotion.curve,
            child: DecoratedBox(decoration: BoxDecoration(color: colors.scrim)),
          ),
          // Media pager — translated vertically by the dismiss drag. While an
          // image is pinch-zoomed the drag handlers detach and paging locks so
          // the InteractiveViewer owns the gesture space.
          GestureDetector(
            onVerticalDragStart: _zoomed ? null : _onDragStart,
            onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
            onVerticalDragEnd: _zoomed ? null : _onDragEnd,
            onVerticalDragCancel: _zoomed ? null : _onDragCancel,
            child: AnimatedSlide(
              offset: Offset(0, height <= 0 ? 0 : _dragOffset / height),
              duration: snapDuration,
              curve: AppMotion.curve,
              child: PageView.builder(
                controller: _controller,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                onPageChanged: (page) => setState(() {
                  _current = page;
                  _zoomed = false;
                }),
                itemCount: widget.items.length,
                itemBuilder: (context, index) => _ViewerPage(
                  item: widget.items[index],
                  onZoomChanged: _onZoomChanged,
                ),
              ),
            ),
          ),
          // Top chrome: close at the start, the {current}/{total} counter at
          // the end. Fades alongside the barrier during dismissal drags.
          Align(
            alignment: AlignmentDirectional.topStart,
            child: AnimatedOpacity(
              opacity: 1.0 - dragFraction,
              duration: snapDuration,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                  child: Row(
                    children: [
                      _FrostedCloseButton(
                        label: l10n.galleryViewerClose,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      GlassPill(
                        label: l10n.galleryViewerCounter(
                          _current + 1,
                          widget.items.length,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Per-kind pages ───────────────────────────────────────────────────────────

/// Routes one media row to its page: panorama → 360° opener, image →
/// pinch-zoomable photo, anything else → the inline gallery's play/placeholder
/// affordance (launching videos in the OS player on tap).
class _ViewerPage extends StatelessWidget {
  const _ViewerPage({required this.item, required this.onZoomChanged});

  final FullscreenGalleryItem item;
  final ValueChanged<bool> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    final media = item.media;
    if (media.isPanorama) {
      return _PanoramaPage(item: item);
    }
    if (media.kind == ListingMediaKind.image && item.imageUrl != null) {
      return _ZoomableImagePage(
        url: item.imageUrl!,
        onZoomChanged: onZoomChanged,
      );
    }
    return _PlaceholderPage(media: media);
  }
}

/// A pinch-zoomable photo. Reports its zoomed/unzoomed state upward so the
/// viewer can suspend paging + drag-to-dismiss while the user pans the zoomed
/// image; `panEnabled` mirrors the same flag so an un-zoomed single-finger
/// drag falls through to the dismiss/page recognizers.
class _ZoomableImagePage extends StatefulWidget {
  const _ZoomableImagePage({required this.url, required this.onZoomChanged});

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImagePage> createState() => _ZoomableImagePageState();
}

class _ZoomableImagePageState extends State<_ZoomableImagePage> {
  final TransformationController _transform = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
      widget.onZoomChanged(zoomed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InteractiveViewer(
      transformationController: _transform,
      maxScale: 4,
      panEnabled: _zoomed,
      onInteractionEnd: _onInteractionEnd,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: widget.url,
          fit: BoxFit.contain,
          placeholder: (_, __) => AppSpinner(color: colors.onPhoto),
          errorWidget: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            size: AppSpacing.xxxl,
            color: colors.onPhoto,
          ),
        ),
      ),
    );
  }
}

/// A panorama row: the equirectangular still with the existing 360° pill
/// centered over it; tapping anywhere opens [PanoramaTourPage] exactly like
/// the inline gallery's affordance does.
class _PanoramaPage extends StatelessWidget {
  const _PanoramaPage({required this.item});

  final FullscreenGalleryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.panoramaTourOpen,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PanoramaTourPage.fromMedia(item.media),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            if (item.imageUrl != null)
              CachedNetworkImage(
                imageUrl: item.imageUrl!,
                fit: BoxFit.contain,
                placeholder: (_, __) => AppSpinner(color: colors.onPhoto),
                errorWidget: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  size: AppSpacing.xxxl,
                  color: colors.onPhoto,
                ),
              )
            else
              Icon(
                Icons.broken_image_outlined,
                size: AppSpacing.xxxl,
                color: colors.onPhoto,
              ),
            Center(
              child: GlassPill(
                label: l10n.panoramaTourBadge,
                icon: Icons.threesixty,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mirrors the inline gallery's non-image affordance (play glyph + label) on
/// the dark scrim; tapping a video row launches the OS player through the
/// same [ListingDetailsVideoLauncher] path the details page uses today.
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.media});

  final ListingMedia media;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isVideo = media.kind == ListingMediaKind.video;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isVideo ? () => ListingDetailsVideoLauncher.launch(media) : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isVideo ? Icons.play_circle_outline : Icons.image_outlined,
            size: AppSpacing.xxxl,
            color: colors.onPhoto,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.mediaGalleryVideoPlay,
            style: styles.bodyMedium.copyWith(color: colors.onPhoto),
          ),
        ],
      ),
    );
  }
}

/// Frosted close affordance over imagery — same photo-overlay treatment as
/// the panorama page's close button, with the Lucide `x` glyph.
class _FrostedCloseButton extends StatelessWidget {
  const _FrostedCloseButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: colors.photoOverlay,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
            child: Icon(
              LucideIcons.x,
              size: AppSpacing.lg,
              color: colors.onPhoto,
            ),
          ),
        ),
      ),
    );
  }
}
