import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/loading_state.dart';

/// Premium uplift — structured loading skeleton for the listing-details page.
///
/// Mirrors the real success layout (gallery → title → price → specs row →
/// location lines → contact block) with shimmer primitives, so the page
/// reads as "the same screen, loading" rather than a bare spinner. Built
/// entirely from [LoadingState] shimmer blocks; token-only + RTL-safe.
class ListingDetailsSkeleton extends StatelessWidget {
  const ListingDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        // Gallery — full-bleed 16:9 hero placeholder (matches the SliverAppBar).
        AspectRatio(aspectRatio: 16 / 9, child: LoadingState.card()),
        Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title — a heading line + a shorter publisher sub-line.
              LoadingState.heading(),
              SizedBox(height: AppSpacing.sm),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 0.45,
                child: LoadingState.line(),
              ),
              SizedBox(height: AppSpacing.lg),
              // Price — a prominent, half-width block.
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 0.4,
                child: LoadingState.heading(),
              ),
              SizedBox(height: AppSpacing.lg),
              // Specs row — three compact fact tiles.
              _SpecsRowSkeleton(),
              SizedBox(height: AppSpacing.lg),
              // Location — two stacked lines, the second shorter.
              LoadingState.line(),
              SizedBox(height: AppSpacing.sm),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 0.6,
                child: LoadingState.line(),
              ),
              SizedBox(height: AppSpacing.xl),
              // Contact block — a card-height placeholder.
              LoadingState.card(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Three equal fact-tile placeholders in a row (beds · baths · area).
class _SpecsRowSkeleton extends StatelessWidget {
  const _SpecsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _SpecTile()),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _SpecTile()),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _SpecTile()),
      ],
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: AppSpacing.xxxl,
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: appRadius(AppRadii.md),
      ),
    );
  }
}
