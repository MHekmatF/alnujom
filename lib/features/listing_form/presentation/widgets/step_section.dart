import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import 'required_field_chip.dart';

/// Phase 25 listing-form uplift — a titled section card used to group the
/// fields on every step of the add-listing flow.
///
/// Wraps [children] in an [AppSurface] with a leading icon badge, a section
/// [title], and an optional one-line [subtitle] helper. Purely presentational:
/// it owns no state and dispatches no events. RTL-safe (directional padding /
/// alignment) and fully token-clean.
class StepSection extends StatelessWidget {
  const StepSection({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Optional trailing affordance pinned to the header (e.g. an Edit button on
  /// the Review step). Does not add new navigation by itself.
  final Widget? trailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return AppSurface(
      radius: AppRadii.lg,
      elevated: true,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: AppSpacing.xl, color: colors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: styles.titleMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: styles.bodyMedium.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

/// A field label with an optional required affordance and helper text. Replaces
/// the ad-hoc `Row(Text titleSmall + RequiredFieldChip)` pattern repeated across
/// every step so spacing and typography stay consistent and token-clean.
class FieldLabel extends StatelessWidget {
  const FieldLabel({
    super.key,
    required this.label,
    this.required = false,
    this.helper,
  });

  final String label;
  final bool required;

  /// Optional inline hint shown beside the label (e.g. "phone or WhatsApp
  /// required"). Kept subtle so the field label still leads.
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              style: styles.labelLarge.copyWith(color: colors.onSurface),
            ),
          ),
          if (helper != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                helper!,
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
              ),
            ),
          ],
          if (required) ...[
            const SizedBox(width: AppSpacing.sm),
            const RequiredFieldChip(),
          ],
        ],
      ),
    );
  }
}

/// Vertical rhythm between fields inside a [StepSection].
class FieldGap extends StatelessWidget {
  const FieldGap({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: AppSpacing.lg);
}
