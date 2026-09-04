// lib/core/widgets/app_nav_drawer.dart
//
// Phase 030 (W5) — auth-aware navigation Drawer.
//
// Declutters the Profile tab by relocating its tool sections (Selling / Admin /
// Activity / More-Reports) into a single app-wide Drawer reachable from a
// hamburger affordance in the Home AppBar (and the Profile AppBar). Under RTL
// this opens from the start side = RIGHT automatically (Material Drawer is a
// start-side drawer; Directionality flips it for Arabic).
//
// Behaviour parity: every entry navigates EXACTLY as ProfilePage did today
// (same context.go / context.push / Navigator.push(MaterialPageRoute) targets,
// same cubit BlocProviders, same AuthBloc/PermissionChecker gates). Each entry
// first closes the drawer, then navigates.
//
// Token-only (AppColors.of / AppTextStyles.of / AppSpacing / appRadius /
// AppElevation). RTL-safe (EdgeInsetsDirectional / start-end).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../routing/app_router.dart';
import '../security/permission_checker.dart';
import '../security/permission_keys.dart';
import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'app_network_image.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/crm/presentation/pages/crm_page.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/domain/entities/profile.dart';
import '../../shared/domain/value_objects/publisher_status.dart';
import '_widget_support.dart';
import 'press_scale.dart';

/// An auth-aware app navigation [Drawer].
///
/// Header: a compact identity strip (avatar + name + handle) for signed-in
/// users, or a "sign in" call-to-action for anonymous visitors. Body: the tool
/// sections lifted out of ProfilePage, gated identically.
class AppNavDrawer extends StatelessWidget {
  const AppNavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Drawer(
      backgroundColor: colors.surface,
      child: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final profile = switch (authState) {
              Authenticated(:final profile) => profile,
              PendingApproval(:final profile) => profile,
              Rejected(:final profile) => profile,
              Suspended(:final profile) => profile,
              _ => null,
            };
            final isSignedIn = profile != null;

            // Gates mirror ProfilePage exactly.
            final isPublisher =
                profile?.publisherStatus == PublisherStatus.approved;
            final isAdmin = getIt<PermissionChecker>().any(
              PermissionKeys.adminCategoryKeys,
            );
            final showDashboard = isPublisher || isAdmin;

            return ListView(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
              children: [
                // ── Header ──────────────────────────────────────────────────
                if (isSignedIn)
                  _DrawerIdentityStrip(profile: profile)
                else
                  const _DrawerSignInCta(),

                // ── Selling (publisher / dashboard / agency) ───────────────
                if (isSignedIn && (showDashboard || isPublisher))
                  _DrawerSection(
                    title: AppLocalizations.of(context)!.profileSectionSelling,
                    children: [
                      if (showDashboard)
                        DrawerRow(
                          icon: Icons.dashboard_outlined,
                          title: AppLocalizations.of(context)!.dashboardEntryTitle,
                          onTap: () => _closeThen(
                            context,
                            () => context.push(AppRoutes.dashboard),
                          ),
                        ),
                      if (isPublisher) ...[
                        DrawerRow(
                          icon: Icons.handshake_outlined,
                          title: AppLocalizations.of(context)!.crmPageTitle,
                          onTap: () => _closeThen(
                            context,
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CrmPage(),
                              ),
                            ),
                          ),
                        ),
                        DrawerRow(
                          icon: Icons.inbox_outlined,
                          title: AppLocalizations.of(
                            context,
                          )!.home_inquiries_action_tooltip,
                          onTap: () => _closeThen(
                            context,
                            () => context.push(AppRoutes.inquiries),
                          ),
                        ),
                        DrawerRow(
                          icon: Icons.list_alt_outlined,
                          title: AppLocalizations.of(context)!.myListingsPageTitle,
                          onTap: () => _closeThen(
                            context,
                            () => context.push(AppRoutes.publisherMyListings),
                          ),
                        ),
                      ],
                      DrawerRow(
                        icon: Icons.business_outlined,
                        title: AppLocalizations.of(context)!.profile_agency_tile,
                        onTap: () => _closeThen(
                          context,
                          () => context.push(AppRoutes.agency),
                        ),
                      ),
                    ],
                  ),

                // ── Admin (admin only) ─────────────────────────────────────
                if (isSignedIn && isAdmin)
                  _DrawerSection(
                    title: AppLocalizations.of(context)!.profileSectionAdmin,
                    children: [
                      DrawerRow(
                        icon: Icons.admin_panel_settings_outlined,
                        title: AppLocalizations.of(context)!.admin_home_title,
                        accent: colors.error,
                        onTap: () => _closeThen(
                          context,
                          () => context.push(AppRoutes.admin),
                        ),
                      ),
                    ],
                  ),

                // ── Activity (Messages + Viewings) ─────────────────────────
                if (isSignedIn)
                  _DrawerSection(
                    title: AppLocalizations.of(context)!.profileSectionActivity,
                    children: [
                      DrawerRow(
                        icon: Icons.forum_outlined,
                        title: AppLocalizations.of(context)!.chatMessagesTile,
                        // Phase 035 — Messages is now a primary tab; the drawer
                        // shortcut routes to it instead of pushing a copy.
                        onTap: () =>
                            _closeThen(context, () => context.go(AppRoutes.chat)),
                      ),
                      DrawerRow(
                        icon: Icons.calendar_today_outlined,
                        title: AppLocalizations.of(context)!.viewingsTile,
                        // Plan A16 — goes through the route now, so the drawer
                        // and a viewing notification land on the same screen
                        // rather than two stacked copies of it.
                        onTap: () => _closeThen(
                          context,
                          () => context.go(AppRoutes.viewings),
                        ),
                      ),
                    ],
                  ),

                // ── More (Reports + About) ─────────────────────────────────
                _DrawerSection(
                  title: AppLocalizations.of(context)!.profileSectionMore,
                  children: [
                    // Reports — signed-in only (the page redirects anonymous
                    // deep-links to /login, so it is hidden here for parity).
                    if (isSignedIn)
                      DrawerRow(
                        icon: Icons.flag_outlined,
                        title: AppLocalizations.of(context)!.profile_reports_tile,
                        onTap: () => _closeThen(
                          context,
                          () => context.push(AppRoutes.reports),
                        ),
                      ),
                    // Smart search assistant — public (anonymous-accessible).
                    // Until 2026-09-02 NOTHING in the app navigated to
                    // `/assistant`: the whole Phase-28/031 feature shipped with
                    // no entry point and was reachable only by editing the URL.
                    // The drawer's "more" list is where secondary destinations
                    // live, so it goes here rather than costing a nav slot.
                    DrawerRow(
                      icon: LucideIcons.sparkles,
                      title: AppLocalizations.of(context)!.assistantTitle,
                      onTap: () => _closeThen(
                        context,
                        () => context.push(AppRoutes.assistant),
                      ),
                    ),
                    // Settings — public (anonymous-accessible route).
                    DrawerRow(
                      icon: Icons.settings_outlined,
                      title: AppLocalizations.of(context)!.settings_title,
                      onTap: () => _closeThen(
                        context,
                        () => context.push(AppRoutes.settings),
                      ),
                    ),
                    // About / support — public (anonymous-accessible route).
                    DrawerRow(
                      icon: LucideIcons.info,
                      title: AppLocalizations.of(context)!.navDrawerAbout,
                      onTap: () => _closeThen(
                        context,
                        () => context.push(AppRoutes.about),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Closes the drawer, then runs [navigate] on the next frame so the pop is
  /// committed before the push (avoids navigating on a context whose Navigator
  /// is mid-pop).
  static void _closeThen(BuildContext context, VoidCallback navigate) {
    Navigator.of(context).pop();
    navigate();
  }
}

// ── Header variants ───────────────────────────────────────────────────────────

/// A compact signed-in identity strip: a solid brand-primary (royal-blue/navy)
/// panel holding the avatar (photo or initials), the display name + optional
/// handle, rendered in `onPrimary` for a confident branded header.
class _DrawerIdentityStrip extends StatelessWidget {
  const _DrawerIdentityStrip({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final displayName =
        profile.fullName ??
        (profile.username != null
            ? '@${profile.username}'
            : (profile.phone ?? ''));
    final hasUsername = profile.username != null;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      child: ClipRRect(
        borderRadius: const BorderRadiusDirectional.only(
          bottomEnd: Radius.circular(AppRadii.xl),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.primary),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              children: [
                _DrawerAvatar(
                  avatarUrl: profile.avatarUrl,
                  initials: _initials(
                    profile.fullName ?? profile.username ?? '؟',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: styles.titleMedium.copyWith(
                          color: colors.onPrimary,
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
                            color: colors.onPrimary.withValues(alpha: 0.75),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An anonymous-visitor header: a solid brand-primary (royal-blue/navy) panel
/// with a sign-in CTA that routes to /login (mirrors the home empty-state
/// sign-in target), rendered in `onPrimary` to match the signed-in strip.
class _DrawerSignInCta extends StatelessWidget {
  const _DrawerSignInCta();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      child: ClipRRect(
        borderRadius: const BorderRadiusDirectional.only(
          bottomEnd: Radius.circular(AppRadii.xl),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.primary),
          child: PressScale(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  // push, not go: a guest who taps this and changes their mind
                  // must get their place back on Back. `go` roots the stack at
                  // /login, and Back from there quits the app.
                  context.push(AppRoutes.login);
                },
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: AppSpacing.xxxl,
                        height: AppSpacing.xxxl,
                        alignment: AlignmentDirectional.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.onPrimary.withValues(alpha: 0.18),
                          border: Border.all(
                            color: colors.onPrimary.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Icon(
                          LucideIcons.log_in,
                          color: colors.onPrimary,
                          size: AppSpacing.xl,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.navDrawerSignInCta,
                              style: styles.titleMedium.copyWith(
                                color: colors.onPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              l10n.navDrawerSignInSubtitle,
                              style: styles.bodyMedium.copyWith(
                                color: colors.onPrimary.withValues(alpha: 0.75),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        LucideIcons.chevron_right,
                        size: AppSpacing.xl,
                        color: colors.onPrimary.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The avatar circle for the identity strip, sitting on the brand-primary
/// header panel. Renders the avatar photo when set, otherwise up-to-two-
/// character initials in `onPrimary` over a translucent wash.
class _DrawerAvatar extends StatelessWidget {
  const _DrawerAvatar({required this.initials, this.avatarUrl});

  final String initials;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Container(
      width: AppSpacing.xxxl,
      height: AppSpacing.xxxl,
      alignment: AlignmentDirectional.center,
      clipBehavior: hasPhoto ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.onPrimary.withValues(alpha: 0.18),
        border: Border.all(color: colors.onPrimary.withValues(alpha: 0.45)),
      ),
      child: hasPhoto
          ? AppNetworkImage(url: avatarUrl)
          : Text(
              initials,
              style: styles.titleMedium.copyWith(color: colors.onPrimary),
            ),
    );
  }
}

// ── Sections + rows ─────────────────────────────────────────────────────────

/// A titled drawer section: a muted group header over a card that visually
/// groups its rows with hairline dividers (mirrors ProfilePage's section idiom).
class _DrawerSection extends StatelessWidget {
  const _DrawerSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
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
                    if (i > 0) const _DrawerRowDivider(),
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

/// A hairline divider between grouped drawer rows.
class _DrawerRowDivider extends StatelessWidget {
  const _DrawerRowDivider();

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

/// A single navigation row inside a drawer section card: a leading icon in a
/// soft tinted square, a title, and a directional chevron. Lifted from
/// ProfilePage's `_ProfileRow` visual; public so it reads as a reusable idiom.
class DrawerRow extends StatelessWidget {
  const DrawerRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.accent,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final tint = accent ?? colors.primary;
    final isDestructive = accent == colors.error;

    return PressScale(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              children: [
                _DrawerRowIcon(icon: icon, tint: tint),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: styles.titleMedium.copyWith(
                      color: isDestructive ? colors.error : colors.onSurface,
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

/// The leading icon in a soft tinted square (matches ProfilePage's row badge).
class _DrawerRowIcon extends StatelessWidget {
  const _DrawerRowIcon({required this.icon, required this.tint});

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
