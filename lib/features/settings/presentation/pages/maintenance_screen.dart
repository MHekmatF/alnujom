import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/support_contact.dart';
import '../bloc/app_settings_cubit.dart';
import '../widgets/support_contact_row.dart';

/// Phase 23 (FC / T021) — the full-screen gate shown to everyone EXCEPT
/// `settings.manage` holders while maintenance mode is active (FR-009/FR-011).
///
/// Renders:
/// - a localized title,
/// - the admin's active-locale custom message via [LocalizedText.forLocale],
///   falling back to built-in copy when unset,
/// - only the [SupportContact] channels that are configured (no broken links),
/// - a **retry** button that re-invokes [AppSettingsCubit.load] so the screen
///   clears automatically once maintenance is turned off.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);

    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, state) {
        final maintenance = state.settings.maintenance;
        final contact = state.settings.supportContact;
        final customMessage = maintenance.message?.forLocale(locale);
        final message = (customMessage != null && customMessage.isNotEmpty)
            ? customMessage
            : l10n.maintenance_default_message;
        final isRetrying = state.status == AppSettingsStatus.loading;
        // Staff-sign-in affordance: only the `settings.manage` bypass gets past
        // the gate, and that requires being signed in. A logged-out operator
        // landing here needs a way to reach /login (which the gate keeps
        // reachable during maintenance — see maintenance_gate.dart).
        final authState = getIt<AuthBloc>().state;
        final showSignIn =
            authState is Unauthenticated || authState is AuthError;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
                child: StaggeredListItem(
                  index: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: AppSpacing.xxxl + AppSpacing.xl,
                        height: AppSpacing.xxxl + AppSpacing.xl,
                        alignment: AlignmentDirectional.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withValues(alpha: 0.10),
                        ),
                        child: Icon(
                          Icons.build_outlined,
                          size: AppSpacing.xxxl,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.maintenance_title,
                        textAlign: TextAlign.center,
                        style: styles.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: styles.bodyLarge.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton.filledPrimary(
                        label: l10n.maintenance_retry,
                        loading: isRetrying,
                        onPressed: isRetrying
                            ? null
                            : () => context.read<AppSettingsCubit>().load(),
                      ),
                      if (showSignIn) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: l10n.auth_required_sign_in_action,
                          variant: AppButtonVariant.text,
                          icon: Icons.login,
                          onPressed: () => context.go(AppRoutes.login),
                        ),
                      ],
                      if (contact.hasAny) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Divider(color: colors.divider),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            l10n.maintenance_support_heading,
                            style: styles.labelLarge.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ..._buildContactRows(l10n, contact),
                      ],
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

  List<Widget> _buildContactRows(
    AppLocalizations l10n,
    SupportContact contact,
  ) {
    final rows = <Widget>[];
    final phone = contact.phone;
    final whatsapp = contact.whatsapp;
    final email = contact.email;
    if (phone != null && phone.isNotEmpty) {
      rows.add(
        SupportContactRow.phone(
          label: l10n.support_channel_phone,
          phone: phone,
        ),
      );
    }
    if (whatsapp != null && whatsapp.isNotEmpty) {
      rows.add(
        SupportContactRow.whatsapp(
          label: l10n.support_channel_whatsapp,
          whatsapp: whatsapp,
        ),
      );
    }
    if (email != null && email.isNotEmpty) {
      rows.add(
        SupportContactRow.email(
          label: l10n.support_channel_email,
          email: email,
        ),
      );
    }
    return rows;
  }
}
