import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '_widget_support.dart';
import 'dimens.dart';
import 'loading_state.dart';

class MapPreview extends StatelessWidget {
  const MapPreview({this.loading = false, this.onTap, super.key});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (loading) return const LoadingState.card();
    final colors = AppColors.of(context);
    return AspectRatio(
      aspectRatio: AppDimens.aspect16x9,
      child: AppSurface(
        onTap: onTap,
        color: colors.primaryContainer,
        radius: AppRadii.md,
        child: Center(
          child: Icon(
            LucideIcons.map_pin,
            color: colors.primary,
            size: AppSpacing.xxxl,
          ),
        ),
      ),
    );
  }
}
