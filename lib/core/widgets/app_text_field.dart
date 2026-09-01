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
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
    this.textDirection,
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

  /// Form validation, so a field inside a [Form] can use this widget instead of
  /// dropping to a bare, unthemed [TextFormField]. Several admin forms (the ad
  /// editor, the currency form, dialog inputs) did exactly that only because
  /// this hook was missing.
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;

  /// Forces the text direction of the field's own content. Leave null to follow
  /// the ambient locale; set it for values that are always LTR regardless of the
  /// UI language, such as phone numbers, prices and currency codes.
  final TextDirection? textDirection;

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
        validator: validator,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        focusNode: focusNode,
        textDirection: textDirection,
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
