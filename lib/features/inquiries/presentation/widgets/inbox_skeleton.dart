// lib/features/inquiries/presentation/widgets/inbox_skeleton.dart
//
// Shared loading skeleton for the inquiry inbox surfaces (publisher inbox +
// admin oversight). Shimmer card rows shaped like the inbox tiles, matching
// the favorites-page skeleton idiom. Token-only.
import 'package:flutter/material.dart';

import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/loading_state.dart';

/// Loading skeleton — shimmer card rows shaped like the inbox tiles, matching
/// the favorites-page skeleton idiom. Shared by the publisher inbox and the
/// admin oversight page so both list surfaces skeleton identically.
class InboxSkeleton extends StatelessWidget {
  const InboxSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsetsDirectional.only(bottom: AppSpacing.md),
        child: AppSurface(
          padding: EdgeInsetsDirectional.all(AppSpacing.lg),
          radius: AppRadii.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 0.45,
                child: LoadingState.heading(),
              ),
              SizedBox(height: AppSpacing.sm),
              LoadingState.line(),
              SizedBox(height: AppSpacing.sm),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 0.7,
                child: LoadingState.line(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
