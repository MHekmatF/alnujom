import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';
import 'app_network_image.dart';
import 'dimens.dart';
import 'loading_state.dart';

class ImageGallery extends StatefulWidget {
  const ImageGallery({
    required this.imageUrls,
    this.loading = false,
    super.key,
  });

  final List<String> imageUrls;
  final bool loading;

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullscreen(int initialIndex) {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: AppColors.of(context).scrim,
        transitionDuration: AppMotion.base,
        pageBuilder: (_, __, ___) => _FullscreenGallery(
          imageUrls: widget.imageUrls,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const LoadingState.card();
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    if (widget.imageUrls.isEmpty) {
      return ColoredBox(
        color: colors.primaryContainer,
        child: Icon(Icons.image, color: colors.primary),
      );
    }
    return ClipRRect(
      borderRadius: appRadius(AppRadii.md),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: AppDimens.aspect16x9,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.imageUrls.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openFullscreen(index),
                child: AppNetworkImage(url: widget.imageUrls[index]),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: AppSpacing.sm,
            end: AppSpacing.sm,
            child: AppSurface(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              color: colors.photoOverlay,
              borderColor: colors.photoOverlay,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.zoom_out_map,
                    size: AppSpacing.md,
                    color: colors.onPhoto,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    AppStrings.of(
                      context,
                    ).loc.paginationCounter(_page + 1, widget.imageUrls.length),
                    style: styles.labelMedium.copyWith(color: colors.onPhoto),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom image viewer opened from [ImageGallery].
///
/// A dark scrim backdrop, a top close affordance + page counter, a horizontal
/// pager across all images, and per-image [InteractiveViewer] pinch-zoom with
/// double-tap-to-zoom. Theme-independent chrome (white on the dark backdrop) by
/// design — the surface behind imagery is always dark.
class _FullscreenGallery extends StatefulWidget {
  const _FullscreenGallery({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) =>
                _ZoomableImage(url: widget.imageUrls[index]),
          ),
          PositionedDirectional(
            top: AppSpacing.sm,
            start: AppSpacing.sm,
            end: AppSpacing.sm,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.close,
                    color: colors.onPhoto,
                    background: colors.photoOverlay,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (widget.imageUrls.length > 1)
                    AppSurface(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      color: colors.photoOverlay,
                      borderColor: colors.photoOverlay,
                      child: Text(
                        AppStrings.of(context).loc.paginationCounter(
                          _index + 1,
                          widget.imageUrls.length,
                        ),
                        style: styles.labelMedium.copyWith(
                          color: colors.onPhoto,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single pinch-zoomable image with double-tap-to-zoom toggling between fit
/// and a 2.5x focus on the tapped point.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url});

  final String url;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: AppMotion.base,
  );
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    final isZoomedIn = _controller.value.getMaxScaleOnAxis() > 1.01;
    final Matrix4 target;
    if (isZoomedIn || position == null) {
      target = Matrix4.identity();
    } else {
      const scale = 2.5;
      // Compose a focal-point zoom (scale about [position]) without the
      // deprecated Matrix4.translate/scale helpers: a uniform scale on the
      // diagonal plus a translation in the last column that keeps the tapped
      // point fixed (translation = -position * (scale - 1)).
      target = Matrix4.diagonal3Values(scale, scale, 1)
        ..setEntry(0, 3, -position.dx * (scale - 1))
        ..setEntry(1, 3, -position.dy * (scale - 1));
    }
    _animation =
        Matrix4Tween(begin: _controller.value, end: target).animate(
          CurvedAnimation(parent: _animController, curve: AppMotion.curve),
        )..addListener(() {
          _controller.value = _animation!.value;
        });
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const LoadingState.card(),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          child: Icon(icon, color: color, size: AppSpacing.lg),
        ),
      ),
    );
  }
}
