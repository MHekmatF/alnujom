import 'package:flutter/widgets.dart';
import 'package:alnujom/core/theme/colors.dart';
import 'package:alnujom/core/theme/radii.dart';
import 'package:alnujom/core/theme/spacing.dart';
import 'package:alnujom/core/theme/typography.dart';

Widget cleanFixture(BuildContext context) {
  final colors = AppColors.of(context);
  final styles = AppTextStyles.of(context);

  return DecoratedBox(
    decoration: BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Text('clean', style: styles.bodyMedium),
    ),
  );
}
