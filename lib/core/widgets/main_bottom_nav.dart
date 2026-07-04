import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../routing/app_router.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';
import 'reduce_motion.dart';

/// The primary destinations of the public app shell.
///
/// Phase 035 (redesign): the app moves to the 5-tab information architecture —
/// Home · Search+Map · Saved · Messages · Account. Reels is no longer a tab
/// (it survives as the Home video-tours rail + the `/reels` deep route). The
/// "أضف عقار" publish action is no longer a bar slot; it is a floating
/// [PublishFab] mounted on each tab host's `Scaffold.floatingActionButton`.
enum MainTab { home, search, favorites, chat, profile, none }

/// Phase 33 restyle — the persistent bottom navigation bar shared by the four
/// primary surfaces (home / reels / favorites / profile).
///
/// A custom bar (not Material's [NavigationBar]) so it can match the design
/// system: a 76px [AppColors.card] bar with a hairline top border, each tab a
/// 23px icon over a 10.5px label, the active tab tinted [AppColors.primary]
/// with a tiny pill indicator above it. Approved publishers get a prominent
/// elevated rounded-square **Publish** action in the centre that floats above
/// the bar and pushes the create-listing form — it never becomes a selected
/// tab. Tab switches use `context.go` so each destination is a clean stack
/// root; deep pages (listing details, agency, etc.) push full-screen over it.
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key, required this.current});

  /// The destination this bar is rendered under (drives the selected slot).
  final MainTab current;

  /// The height of the bar's content (excluding the bottom safe-area inset).
  static const double _barHeight = 76;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final reduce = reduceMotion(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isSignedIn =
            authState is Authenticated ||
            authState is PendingApproval ||
            authState is Rejected ||
            authState is Suspended;

        final highlightNone = current == MainTab.none;

        // Phase 035 — five equal tabs: Home · Search+Map · Saved · Messages ·
        // Account. Messages + Account are auth-gated (anonymous taps route to
        // sign-in). The publish action is now the floating [PublishFab].
        final slots = <Widget>[
          _NavTab(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: l10n.home_title,
            selected: !highlightNone && current == MainTab.home,
            bounce: !reduce && current == MainTab.home,
            onTap: () => context.go(AppRoutes.home),
          ),
          _NavTab(
            icon: Icons.search_rounded,
            selectedIcon: Icons.travel_explore,
            label: l10n.nav_search_map,
            selected: !highlightNone && current == MainTab.search,
            bounce: !reduce && current == MainTab.search,
            onTap: () => context.go(AppRoutes.search),
          ),
          _NavTab(
            icon: Icons.favorite_border,
            selectedIcon: Icons.favorite,
            label: l10n.favorites_page_title,
            selected: !highlightNone && current == MainTab.favorites,
            bounce: !reduce && current == MainTab.favorites,
            onTap: () => context.go(AppRoutes.favorites),
          ),
          _NavTab(
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
            label: l10n.nav_messages,
            selected: !highlightNone && current == MainTab.chat,
            bounce: !reduce && current == MainTab.chat,
            // Anonymous users tapping Messages are sent to sign-in.
            onTap: () =>
                context.go(isSignedIn ? AppRoutes.chat : AppRoutes.login),
          ),
          _NavTab(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: l10n.profile_title,
            selected: !highlightNone && current == MainTab.profile,
            bounce: !reduce && current == MainTab.profile,
            // Anonymous users tapping Account are sent to sign-in instead of
            // the (auth-only) profile screen.
            onTap: () =>
                context.go(isSignedIn ? AppRoutes.profile : AppRoutes.login),
          ),
        ];

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            border: BorderDirectional(
              top: BorderSide(color: colors.outline),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: _barHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final slot in slots) Expanded(child: slot),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A single bottom-nav tab — a 23px icon over a 10.5px label, tinted
/// [AppColors.primary] when selected (with a tiny pill indicator above it and
/// a bolder label) and [AppColors.textMuted] otherwise.
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.bounce,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool bounce;
  final VoidCallback onTap;

  static const double _iconSize = 23;
  static const double _labelSize = 10.5;
  static const double _indicatorWidth = 16;
  static const double _indicatorHeight = 3;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final fg = selected ? colors.primary : colors.textMuted;

    Widget glyph = Icon(selected ? selectedIcon : icon, size: _iconSize);
    if (bounce) {
      glyph = glyph
          .animate()
          .scaleXY(
            begin: 0.8,
            end: 1.0,
            duration: AppMotion.slow,
            curve: Curves.easeOutBack,
          );
    }

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tiny pill indicator above the selected tab (transparent otherwise
          // so the row never reflows between selected states).
          Container(
            width: _indicatorWidth,
            height: _indicatorHeight,
            decoration: BoxDecoration(
              color: selected ? colors.primary : Colors.transparent,
              borderRadius: appRadius(AppRadii.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          IconTheme(
            data: IconThemeData(color: fg, size: _iconSize),
            child: glyph,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.labelMedium.copyWith(
              fontSize: _labelSize,
              color: fg,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

