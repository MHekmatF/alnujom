// Plan A30 — a slim strip along the top edge while the phone has no network.
//
// Mounted once, above the whole navigator (see app.dart), so every screen
// gets it without knowing. It ignores pointer events and paints only from
// theme tokens, so it reads the same in light and dark.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/connectivity_cubit.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../../l10n/app_localizations.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, bool>(
      builder: (context, online) {
        if (online) return const SizedBox.shrink();
        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);
        final l10n = AppLocalizations.of(context)!;
        return Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: Material(
              color: colors.error,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: AppSpacing.lg,
                        color: colors.onError,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          l10n.errorOffline,
                          style: styles.labelMedium.copyWith(
                            color: colors.onError,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
