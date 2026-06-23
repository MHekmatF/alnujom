import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';

/// Phase 033 auth restyle — a labelled "big field" matching the add-listing
/// Express form aesthetic: a label sitting above a tall (~58px), filled, rounded
/// input with a 1.5px outline border that turns `primary` on focus.
///
/// Purely presentational — every control still hosts a plain [TextFormField]
/// owned by the caller (so all existing validators / controllers / onChanged
/// wiring stays intact).
class AuthField extends StatelessWidget {
  const AuthField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: styles.labelLarge.copyWith(color: colors.onSurface),
          ),
        ),
        child,
      ],
    );
  }
}

/// Minimum height for the auth "big field" shell (~58 in the design).
const double _kAuthFieldMinHeight = 58;

/// Shared big-field decoration (tall, filled, rounded) for the auth surfaces —
/// the DS `.field-big` look: `surfaceVariant` fill, 1.5px `outline` border,
/// md radius, `primary` on focus. The label lives above (via [AuthField]); the
/// in-field [hint] carries any placeholder text.
InputDecoration authFieldDecoration(
  BuildContext context, {
  String? hint,
  Widget? suffixIcon,
}) {
  final colors = AppColors.of(context);
  final styles = AppTextStyles.of(context);
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: appRadius(AppRadii.md),
    borderSide: BorderSide(color: color, width: 1.5),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: styles.bodyLarge.copyWith(color: colors.textMuted),
    filled: true,
    fillColor: colors.surfaceVariant,
    suffixIcon: suffixIcon,
    constraints: const BoxConstraints(minHeight: _kAuthFieldMinHeight),
    contentPadding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    enabledBorder: border(colors.outline),
    border: border(colors.outline),
    focusedBorder: border(colors.primary),
    errorBorder: border(colors.error),
    focusedErrorBorder: border(colors.error),
  );
}
