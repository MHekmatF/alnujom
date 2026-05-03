import 'package:flutter/material.dart';

import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.headline,
    this.body,
    this.illustration,
    this.ctaLabel,
    this.onCtaPressed,
    super.key,
  });

  final String headline;
  final String? body;
  final Widget? illustration;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null) ...[
              illustration!,
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              headline,
              textAlign: TextAlign.center,
              style: styles.titleLarge,
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: styles.bodyMedium,
              ),
            ],
            if (ctaLabel != null && onCtaPressed != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: ctaLabel!, onPressed: onCtaPressed),
            ],
          ],
        ),
      ),
    );
  }
}
