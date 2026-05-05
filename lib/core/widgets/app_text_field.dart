import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';
import 'dimens.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.initialValue,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
    this.prefix,
    this.suffix,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final bool obscureText;
  final int? maxLines;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kAppMinTouchTarget),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        enabled: enabled,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: styles.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: styles.bodyMedium,
          helperText: errorText == null ? helperText : null,
          helperStyle: styles.labelMedium,
          errorText: errorText,
          errorStyle: styles.labelMedium.copyWith(color: colors.error),
          prefixIcon: prefix == null ? null : AppTapTarget(child: prefix!),
          suffixIcon: suffix == null ? null : AppTapTarget(child: suffix!),
          filled: true,
          fillColor: enabled ? colors.card : colors.surfaceVariant,
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: appRadius(AppRadii.md),
            borderSide: BorderSide(color: colors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: appRadius(AppRadii.md),
            borderSide: BorderSide(
              color: colors.primary,
              width: AppDimens.strokeMedium, // visible focus distinction (2 dp)
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: appRadius(AppRadii.md),
            borderSide: BorderSide(color: colors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: appRadius(AppRadii.md),
            borderSide: BorderSide(
              color: colors.error,
              width: AppDimens.strokeMedium, // visible focus distinction (2 dp)
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: appRadius(AppRadii.md),
            borderSide: BorderSide(color: colors.outline),
          ),
        ),
      ),
    );
  }
}
