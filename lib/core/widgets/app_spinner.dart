import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'dimens.dart';

/// Branded circular spinner — the explicit replacement for bare
/// `CircularProgressIndicator()` call-sites (Phase 28). List/queue screens
/// should prefer `LoadingState` skeletons; this is for compact in-flow
/// waits (detail pages, footers, inline refreshes).
class AppSpinner extends StatelessWidget {
  const AppSpinner({this.size = AppSpacing.xl, this.color, super.key});

  /// Full-screen/page-body variant: a centered, comfortably sized spinner.
  const AppSpinner.page({Key? key}) : this(size: AppSpacing.xxl, key: key);

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          strokeWidth: AppDimens.strokeThin,
          valueColor: AlwaysStoppedAnimation<Color>(color ?? colors.primary),
        ),
      ),
    );
  }
}
