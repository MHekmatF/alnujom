import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../localization/app_strings.dart';
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
    final styles = AppTextStyles.of(context);
    final loc = AppStrings.of(context).loc;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: StaggeredListItem(
          index: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PoppingIcon(
                icon: variant == ErrorStateVariant.network
                    ? LucideIcons.wifi_off
                    : LucideIcons.circle_alert,
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: styles.titleLarge,
                ),
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
                label: loc.errorRetryAction,
                variant: AppButtonVariant.tonal,
                icon: LucideIcons.refresh_cw,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The error glyph in a soft tinted circle. The whole [ErrorState] already
/// fades + slides in via [StaggeredListItem], so the glyph itself stays static.
class _PoppingIcon extends StatelessWidget {
  const _PoppingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // DC error badge: an 88px red-container circle with a 44px glyph.
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.errorContainer,
      ),
      child: Icon(icon, color: colors.onErrorContainer, size: 44),
    );
  }
}
