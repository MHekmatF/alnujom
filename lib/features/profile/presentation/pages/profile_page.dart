import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/main_bottom_nav.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
import '../../../../shared/domain/value_objects/publisher_status.dart';
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
            bottomNavigationBar: const MainBottomNav(current: MainTab.profile),
          );
        }

        final profile = state.profile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.profile_title)),
            bottomNavigationBar: const MainBottomNav(current: MainTab.profile),
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
          bottomNavigationBar: const MainBottomNav(current: MainTab.profile),
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
                // Phase 25 (Claude Design) — identity header: avatar initials +
                // name + account-status badge.
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        _initials(profile.fullName ?? profile.username ?? '؟'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName ??
                                (profile.username != null
                                    ? '@${profile.username}'
                                    : (profile.phone ?? '')),
                            style: theme.textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _StatusBadge(profile.accountStatus),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.favorite_border),
                  title: Text(l10n.profile_favorites_tile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.favorites),
                ),
                // Phase 19 — My Agency tile (T059)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.business_outlined),
                  title: Text(l10n.profile_agency_tile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.agency),
                ),
                // Phase 18 — My Reports tile (T051)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(l10n.profile_reports_tile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.reports),
                ),
                // Phase 25 uplift v2 — role-aware Dashboard entry (publisher KPIs
                // or admin console, resolved inside DashboardEntryPage).
                if (profile.publisherStatus == PublisherStatus.approved ||
                    getIt<PermissionChecker>().any(
                      PermissionKeys.adminCategoryKeys,
                    ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.dashboard_outlined),
                    title: Text(l10n.dashboardEntryTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.dashboard),
                  ),
                // Phase 25 — relocated from the Home AppBar (which the bottom-nav
                // restyle slimmed down) so they stay reachable.
                // Publisher-only: inquiries inbox + my listings.
                if (profile.publisherStatus == PublisherStatus.approved) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inbox_outlined),
                    title: Text(l10n.home_inquiries_action_tooltip),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.inquiries),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.list_alt_outlined),
                    title: Text(l10n.myListingsPageTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.publisherMyListings),
                  ),
                ],
                // Admin-only: the sole in-app entry to the admin home.
                if (getIt<PermissionChecker>().any(
                  PermissionKeys.adminCategoryKeys,
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: Text(l10n.admin_home_title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.admin),
                  ),
                const Divider(height: AppSpacing.xl),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text(
                    l10n.sign_out,
                    style: AppTextStyles.of(
                      context,
                    ).bodyLarge.copyWith(color: theme.colorScheme.error),
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

/// Up-to-two-character avatar initials from a display name.
String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '؟';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1);
  }
  return parts.first.substring(0, 1) + parts.last.substring(0, 1);
}
