import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';
import 'app_badge.dart';
import 'dimens.dart';
import 'loading_state.dart';
import 'price_tag.dart';

enum PropertyCardLayout { vertical, horizontal }

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    required this.title,
    required this.price,
    required this.location,
    this.currency = 'ل.س',
    this.imageUrl,
    this.layout = PropertyCardLayout.vertical,
    this.loading = false,
    this.featured = false,
    this.favorite = false,
    this.featuredLabel = 'مميز',
    this.onTap,
    this.onLongPress,
    this.onFavoritePressed,
    this.agencyBadge,
    super.key,
  });

  final String title;
  final String price;
  final String currency;
  final String location;
  final String? imageUrl;
  final PropertyCardLayout layout;
  final bool loading;
  final bool featured;
  final bool favorite;
  final String featuredLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoritePressed;

  /// Phase 19 (FR-022/FR-023) — optional verified-agency badge rendered below
  /// the location row. Rendered ONLY when non-null; passing null leaves the
  /// existing layout completely unchanged (no reflow).
  final Widget? agencyBadge;

  @override
  Widget build(BuildContext context) {
    if (loading) return const LoadingState.card();
    return GestureDetector(
      onLongPress: onLongPress,
      child: AppSurface(
        onTap: onTap,
        elevated: true,
        padding: EdgeInsets.zero,
        child: layout == PropertyCardLayout.horizontal
            ? _horizontal(context)
            : _vertical(context),
      ),
    );
  }

  Widget _vertical(BuildContext context) {
    return SizedBox(
      width: AppDimens.propertyCardVerticalWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: AppDimens.aspect4x3, child: _image(context)),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: _body(context),
          ),
        ],
      ),
    );
  }

  Widget _horizontal(BuildContext context) {
    return SizedBox(
      width: AppDimens.propertyCardHorizontalWidth,
      child: Row(
        children: [
          SizedBox(
            width: AppDimens.propertyCardHorizontalImageWidth,
            child: AspectRatio(
              aspectRatio: AppDimens.aspect16x10,
              child: _image(context),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: _body(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: styles.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        PriceTag(amount: price, currency: currency),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(LucideIcons.map_pin, size: AppSpacing.lg),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.bodyMedium,
              ),
            ),
          ],
        ),
        if (agencyBadge != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: agencyBadge,
          ),
        ],
      ],
    );
  }

  Widget _image(BuildContext context) {
    final colors = AppColors.of(context);
    final placeholder = ColoredBox(
      color: colors.primaryContainer,
      child: Center(child: Icon(LucideIcons.image, color: colors.primary)),
    );
    return ClipRRect(
      borderRadius: appRadius(AppRadii.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl == null || imageUrl!.isEmpty)
            placeholder
          else
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => placeholder,
            ),
          PositionedDirectional(
            top: AppSpacing.sm,
            start: AppSpacing.sm,
            child: featured
                ? AppBadge(
                    label: featuredLabel,
                    variant: AppBadgeVariant.featured,
                  )
                : const SizedBox.shrink(),
          ),
          if (onFavoritePressed != null)
            PositionedDirectional(
              top: AppSpacing.sm,
              end: AppSpacing.sm,
              child: _FavoriteChip(
                favorite: favorite,
                onPressed: onFavoritePressed!,
              ),
            ),
        ],
      ),
    );
  }
}

/// White over-photo heart chip for the generic [PropertyCard] (callback-based;
/// mirrors the cubit-backed `FavoriteHeartButton` over-image treatment).
class _FavoriteChip extends StatelessWidget {
  const _FavoriteChip({required this.favorite, required this.onPressed});

  final bool favorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final elevation = AppElevation.of(context);
    return DecoratedBox(
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
            child: Icon(
              favorite ? Icons.favorite : Icons.favorite_border,
              size: AppSpacing.xl,
              color: favorite ? colors.accent : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
