import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
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
    final theme = Theme.of(context);
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
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.build_outlined,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.maintenance_title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: isRetrying
                          ? null
                          : () => context.read<AppSettingsCubit>().load(),
                      icon: isRetrying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(l10n.maintenance_retry),
                    ),
                    if (showSignIn) ...[
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: () => context.go(AppRoutes.login),
                        icon: const Icon(Icons.login),
                        label: Text(l10n.auth_required_sign_in_action),
                      ),
                    ],
                    if (contact.hasAny) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Divider(color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.maintenance_support_heading,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
