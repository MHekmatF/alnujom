import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'app_button.dart';
import 'staggered_list_item.dart';

enum ErrorStateVariant { defaultState, network }

class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    required this.onRetry,
    this.message,
    this.variant = ErrorStateVariant.defaultState,
    super.key,
  });

  final String title;
  final String? message;
  final ErrorStateVariant variant;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: StaggeredListItem(
          index: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                variant == ErrorStateVariant.network
                    ? LucideIcons.wifi_off
                    : LucideIcons.circle_alert,
                color: colors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: styles.titleLarge,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: styles.bodyMedium,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Retry',
                variant: AppButtonVariant.outlined,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
