// lib/features/profile/presentation/pages/profile_page.dart
//
// Phase 25 (Claude Design) — premium, organized profile.
//
// PURELY VISUAL restyle: every existing element, onTap, gate, route, and l10n
// string is preserved 1:1. The flat list of ListTiles is regrouped into a
// premium identity-header card (gradient brand wash + avatar + status badge +
// role chips + inline phone/email + Edit affordance) and titled sections of
// card-grouped rows (Account / Activity / Selling / Admin / More), mirroring the
// admin console section grouping + the AppDashboardTile idiom. Sign out sits on
// its own, destructive-styled.
//
// Token-only (AppColors.of / AppTextStyles.of / AppSpacing / appRadius /
// AppElevation / AppGradients). RTL-safe (EdgeInsetsDirectional / start-end).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/settings/lite_mode.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/gradients.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_nav_drawer.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/main_bottom_nav.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/entities/profile.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../currencies/presentation/widgets/preferred_currency_toggle.dart';
import '../../domain/entities/assigned_role.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final localeCode = context.read<LocaleCubit>().state.languageCode;
    // Warm the Data saver flag so its switch reflects the saved state.
    LiteMode.load();
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
            body: const AppSpinner.page(),
            bottomNavigationBar: const MainBottomNav(current: MainTab.profile),
          );
        }

        final profile = state.profile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.profile_title)),
            bottomNavigationBar: const MainBottomNav(current: MainTab.profile),
            body: ErrorState(
              title: l10n.profileLoadErrorTitle,
              message: state.failure?.message ?? l10n.unknown_auth_error,
              variant: ErrorStateVariant.network,
              onRetry: () => context.read<ProfileCubit>().load(),
            ),
          );
        }

        return Scaffold(
          bottomNavigationBar: const MainBottomNav(current: MainTab.profile),
          // Phase 030 (W5) — the relocated tool sections (Selling / Admin /
          // Activity / Reports) live in this app-wide navigation drawer. The
          // profile body below is now a focused identity + account surface.
          drawer: const AppNavDrawer(),
          appBar: AppBar(
            title: Text(l10n.profile_title),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Premium identity header ────────────────────────────────
                StaggeredListItem(
                  index: 0,
                  child: _IdentityHeader(profile: profile, roles: state.roles),
                ),

                // ── Account ────────────────────────────────────────────────
                StaggeredListItem(
                  index: 1,
                  child: _ProfileSection(
                    title: l10n.profileSectionAccount,
                    children: [
                    _ProfileRow(
                      icon: Icons.lock_outline,
                      title: l10n.profile_private_section_title,
                      onTap: () => context.push(AppRoutes.profilePrivate),
                    ),
                    _ProfileRow(
                      icon: Icons.favorite_border,
                      title: l10n.profile_favorites_tile,
                      onTap: () => context.push(AppRoutes.favorites),
                    ),
                    // Preferred display currency selector (FR — unchanged
                    // local-state widget). Hosted in a card slot so it reads as
                    // part of the Account group.
                    const _ProfileCardSlot(child: PreferredCurrencyToggle()),
                    // Data saver (lite / low-data) mode — reduces image
                    // resolution and map tile cost for low-bandwidth networks.
                    ValueListenableBuilder<bool>(
                      valueListenable: LiteMode.notifier,
                      builder: (context, lite, _) => _ProfileSwitchRow(
                        icon: Icons.data_saver_on_outlined,
                        title: l10n.profile_data_saver_title,
                        subtitle: l10n.profile_data_saver_subtitle,
                        value: lite,
                        onChanged: (value) => LiteMode.set(value),
                      ),
                    ),
                    ],
                  ),
                ),

                // Phase 030 (W5) — the tool sections previously listed here
                // (Activity = Messages/Viewings; Selling = Dashboard/CRM/
                // Inquiries/My Listings/Agency; Admin = Admin Home; More =
                // Reports) moved into the app navigation drawer (AppNavDrawer),
                // leaving the profile a focused identity + account surface.

                // ── Sign out (destructive, visually separated) ─────────────
                const SizedBox(height: AppSpacing.sm),
                StaggeredListItem(
                  index: 2,
                  child: _SignOutButton(
                    onSignOut: () {
                    // Dispatch logout first so the AuthBloc transitions to
                    // Unauthenticated before we leave the page. Then pop the
                    // pushed /profile route off the stack manually — relying on
                    // refreshListenable to re-evaluate the redirect doesn't work
                    // here because go_router evaluates against the underlying
                    // `/` (now public), not the pushed /profile route.
                    context.read<AuthBloc>().add(const LogoutRequested());
                    context.go(AppRoutes.home);
                  },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Identity header ───────────────────────────────────────────────────────────

/// A premium identity card: a gradient brand-washed surface holding the avatar
/// (initials), the name, the account-status badge, role chips, the phone/email
/// shown inline as compact rows, and a clear Edit affordance.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.profile, required this.roles});

  final Profile profile;
  final List<AssignedRole> roles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final gradients = AppGradients.of(context);

    final displayName =
        profile.fullName ??
        (profile.username != null
            ? '@${profile.username}'
            : (profile.phone ?? ''));

    final hasUsername = profile.username != null;
    final hasPhone = profile.phone != null;
    final hasEmail = profile.email != null && profile.email!.isNotEmpty;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.xl),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level2,
      ),
      child: ClipRRect(
        borderRadius: appRadius(AppRadii.xl),
        child: DecoratedBox(
          // Whisper-soft brand wash so the header reads as the premium hero.
          decoration: BoxDecoration(gradient: gradients.featuredTint),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(
                      avatarUrl: profile.avatarUrl,
                      initials: _initials(
                        profile.fullName ?? profile.username ?? '؟',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: styles.titleLarge.copyWith(
                              color: colors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasUsername) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.profile_username_handle(profile.username!),
                              style: styles.bodyMedium.copyWith(
                                color: colors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          _StatusBadge(profile.accountStatus),
                        ],
                      ),
                    ),
                  ],
                ),
                // Inline contact rows (phone / email).
                if (hasPhone || hasEmail) ...[
                  const SizedBox(height: AppSpacing.lg),
                  if (hasPhone)
                    _ContactRow(
                      icon: Icons.phone_outlined,
                      label: l10n.profile_phone_label,
                      value: profile.phone!,
                    ),
                  if (hasEmail) ...[
                    if (hasPhone) const SizedBox(height: AppSpacing.sm),
                    _ContactRow(
                      icon: Icons.mail_outline,
                      label: l10n.profile_email_label,
                      value: profile.email!,
                    ),
                  ],
                ],
                // Role chips.
                if (roles.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final role in roles)
                        _RoleChip(label: role.displayName),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                // Edit affordance — clear, full-width within the card.
                AppButton(
                  variant: AppButtonVariant.outlined,
                  size: AppButtonSize.dense,
                  expanded: true,
                  icon: Icons.edit_outlined,
                  label: l10n.profile_edit_button,
                  onPressed: () => context.push(AppRoutes.profileEdit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar circle. Renders the user's avatar photo when set (matching the home
/// header), otherwise up-to-two-character initials tinted with the brand
/// primary container.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.avatarUrl});

  final String initials;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Container(
      width: AppSpacing.xxxl + AppSpacing.lg,
      height: AppSpacing.xxxl + AppSpacing.lg,
      alignment: AlignmentDirectional.center,
      clipBehavior: hasPhoto ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primaryContainer,
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: hasPhoto
          ? AppNetworkImage(url: avatarUrl)
          : Text(
              initials,
              style: styles.titleLarge.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
    );
  }
}

/// An inline compact contact row (icon + label + value) inside the header.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Row(
      children: [
        Icon(icon, size: AppSpacing.lg, color: colors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: styles.labelMedium.copyWith(color: colors.textMuted),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: styles.bodyMedium.copyWith(color: colors.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// A soft tonal role chip.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: colors.primary.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: styles.labelMedium.copyWith(color: colors.primary),
      ),
    );
  }
}

/// The account-status badge (token-clean rebuild of the original).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final label = switch (status) {
      AccountStatus.pending => l10n.profile_account_status_badge_pending,
      AccountStatus.approved => l10n.profile_account_status_badge_approved,
      AccountStatus.rejected => l10n.profile_account_status_badge_rejected,
      AccountStatus.suspended => l10n.profile_account_status_badge_suspended,
      AccountStatus.deleted => status.name,
    };

    // Approved reads as a trusted "verified" pill (dedicated DS verified token);
    // the other states keep their semantic warning/error/muted tones.
    final isApproved = status == AccountStatus.approved;

    final color = switch (status) {
      AccountStatus.approved => colors.verified,
      AccountStatus.pending => colors.warning,
      AccountStatus.rejected || AccountStatus.suspended => colors.error,
      _ => colors.textMuted,
    };

    final icon = switch (status) {
      AccountStatus.approved => Icons.verified,
      AccountStatus.pending => Icons.hourglass_empty_outlined,
      AccountStatus.rejected || AccountStatus.suspended => Icons.block_outlined,
      _ => Icons.info_outline,
    };

    final background = isApproved
        ? colors.verifiedContainer
        : color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSpacing.md, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: styles.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Sections + rows ─────────────────────────────────────────────────────────

/// A titled section: a muted group header (matching the admin console idiom)
/// over a card that visually groups its rows with hairline dividers.
class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title,
              style: styles.labelLarge.copyWith(color: colors.textMuted),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: appRadius(AppRadii.lg),
              border: Border.all(color: colors.outline),
              boxShadow: elevation.level1,
            ),
            child: ClipRRect(
              borderRadius: appRadius(AppRadii.lg),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) _RowDivider(),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A hairline divider between grouped rows, inset past the leading icon.
class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.divider,
      indent: AppSpacing.lg,
      endIndent: AppSpacing.lg,
    );
  }
}

/// A single navigation row inside a section card: a leading icon in a soft
/// tinted container, a title, optional subtitle, and a directional chevron.
/// Mirrors the AppDashboardTile idiom; adds a PressScale tap feedback.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return PressScale(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              children: [
                _RowIcon(icon: icon, tint: colors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: styles.titleMedium.copyWith(
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right,
                  size: AppSpacing.xl,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A switch row inside a section card (Data saver). Keeps the leading tinted
/// icon + title + subtitle idiom; the trailing chevron is replaced by a Switch.
class _ProfileSwitchRow extends StatelessWidget {
  const _ProfileSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return PressScale(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              children: [
                _RowIcon(icon: icon, tint: colors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: styles.titleMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: styles.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// A non-tappable card slot for hosting an existing composed widget (the
/// PreferredCurrencyToggle) inside a section card with consistent padding.
class _ProfileCardSlot extends StatelessWidget {
  const _ProfileCardSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: child,
    );
  }
}

/// The leading icon in a soft tinted square (matches AppDashboardTile's badge).
class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.xxl + AppSpacing.sm,
      height: AppSpacing.xxl + AppSpacing.sm,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: appRadius(AppRadii.md),
      ),
      child: Icon(icon, color: tint, size: AppSpacing.xl),
    );
  }
}

// ── Sign out ─────────────────────────────────────────────────────────────────

/// The destructive Sign out action, visually separated on its own card.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return PressScale(
      child: Material(
        color: colors.error.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: appRadius(AppRadii.lg),
          side: BorderSide(color: colors.error.withValues(alpha: 0.30)),
        ),
        child: InkWell(
          borderRadius: appRadius(AppRadii.lg),
          onTap: onSignOut,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: colors.error, size: AppSpacing.xl),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.sign_out,
                  style: styles.labelLarge.copyWith(color: colors.error),
                ),
              ],
            ),
          ),
        ),
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
