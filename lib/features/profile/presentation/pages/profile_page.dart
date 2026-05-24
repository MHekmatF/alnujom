import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../currencies/presentation/widgets/preferred_currency_toggle.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final localeCode = context.read<LocaleCubit>().state.languageCode;
    return BlocProvider<ProfileCubit>(
      create: (_) => getIt<ProfileCubit>()
        ..load()
        ..loadRoles(localeCode),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state.status == ProfileStatus.loading ||
            state.status == ProfileStatus.initial) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.profile_title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final profile = state.profile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.profile_title)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.failure?.message ?? l10n.unknown_auth_error,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.read<ProfileCubit>().load(),
                    child: Text(l10n.errorRetryAction),
                  ),
                ],
              ),
            ),
          );
        }

        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.profile_title),
            actions: [
              TextButton(
                onPressed: () => context.push(AppRoutes.profileEdit),
                child: Text(l10n.profile_edit_button),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBadge(profile.accountStatus),
                const SizedBox(height: 16),
                if (profile.fullName != null)
                  _InfoRow(l10n.profile_full_name_label, profile.fullName!),
                if (profile.username != null)
                  _InfoRow(l10n.profile_username_label, '@${profile.username}'),
                if (profile.phone != null)
                  _InfoRow(l10n.profile_phone_label, profile.phone!),
                if (profile.email != null && profile.email!.isNotEmpty)
                  _InfoRow(l10n.profile_email_label, profile.email!),
                const SizedBox(height: 24),
                if (state.roles.isNotEmpty) ...[
                  Text(
                    l10n.profile_section_roles,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final role in state.roles)
                        Chip(
                          label: Text(
                            role.displayName,
                            style: theme.textTheme.labelMedium,
                          ),
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const PreferredCurrencyToggle(),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: Text(l10n.profile_private_section_title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.profilePrivate),
                ),
                const Divider(height: AppSpacing.xl),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.logout,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    l10n.sign_out,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () {
                    // Dispatch logout first so the AuthBloc transitions to
                    // Unauthenticated before we leave the page. Then pop the
                    // pushed /profile route off the stack manually — relying
                    // on refreshListenable to re-evaluate the redirect doesn't
                    // work here because go_router evaluates against the
                    // underlying `/` (which is now public), not the pushed
                    // /profile route.
                    context.read<AuthBloc>().add(const LogoutRequested());
                    context.go(AppRoutes.home);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final label = switch (status) {
      AccountStatus.pending => l10n.profile_account_status_badge_pending,
      AccountStatus.approved => l10n.profile_account_status_badge_approved,
      AccountStatus.rejected => l10n.profile_account_status_badge_rejected,
      AccountStatus.suspended => l10n.profile_account_status_badge_suspended,
      AccountStatus.deleted => status.name,
    };

    final color = switch (status) {
      AccountStatus.approved => theme.colorScheme.primary,
      AccountStatus.pending => theme.colorScheme.secondary,
      AccountStatus.rejected ||
      AccountStatus.suspended => theme.colorScheme.error,
      _ => theme.colorScheme.outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
