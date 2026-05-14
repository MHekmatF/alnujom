import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (_) => getIt<ProfileCubit>()..load(),
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
            padding: const EdgeInsets.all(16),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: Text(l10n.profile_private_section_title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.profilePrivate),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
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
      padding: const EdgeInsets.only(bottom: 12),
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
