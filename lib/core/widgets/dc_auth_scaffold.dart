import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../../l10n/app_localizations.dart';
import '_widget_support.dart';
import 'brand_mark.dart';

/// The DC "Blue Crown" auth shell (`AlNujom.dc.html` §AUTH): a brand-blue top
/// carrying the star logo + "النجوم" wordmark, over a white sheet (rounded top)
/// that scrolls the auth form. Login / register / reset / OTP all pass their
/// form as [child]; the page-specific headline lives at the top of that form.
class DcAuthScaffold extends StatelessWidget {
  const DcAuthScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: colors.brandHeader,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(
              top: topInset + AppSpacing.xxl,
              bottom: AppSpacing.xl,
              start: AppSpacing.xl,
              end: AppSpacing.xl,
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.onBrandHeader,
                    borderRadius: appRadius(AppRadii.lg),
                  ),
                  child: const BrandMark(size: 38),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.home_app_bar_title,
                  style: styles.headlineMedium.copyWith(
                    color: colors.onBrandHeader,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadiusDirectional.vertical(
                  top: Radius.circular(AppRadii.sheet),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
