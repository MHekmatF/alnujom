import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '_widget_support.dart';

class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({required this.child, this.footer, super.key});

  final Widget child;
  final Widget? footer;

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    Widget? footer,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AppBottomSheet(footer: footer, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FractionallySizedBox(
      heightFactor: 0.85,
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: AppSpacing.xxl,
              height: AppSpacing.xs,
              decoration: BoxDecoration(
                color: colors.outlineStrong,
                borderRadius: appRadius(AppRadii.pill),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: child,
              ),
            ),
            if (footer != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.outline)),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: footer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
