import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/colors.dart';
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
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrls[index],
                      ),
                    ),
                  ),
                ),
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
              color: colors.onSurface.withAlpha(0x99),
              child: Text(
                AppStrings.of(
                  context,
                ).loc.paginationCounter(_page + 1, widget.imageUrls.length),
                style: styles.labelMedium.copyWith(color: colors.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
