import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../routing/app_router.dart';
import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/gradients.dart';
import '../theme/motion.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';
import 'glass.dart';
import 'reduce_motion.dart';

/// The primary destinations of the public app shell.
///
/// Phase 035 (redesign): the app moves to the 5-tab information architecture —
/// Home · Search+Map · Saved · Messages · Account. Reels is no longer a tab
/// (it survives as the Home video-tours rail + the `/reels` deep route). The
/// "أضف عقار" publish action is no longer a bar slot; it is a floating
/// [PublishFab] mounted on each tab host's `Scaffold.floatingActionButton`.
enum MainTab { home, search, favorites, chat, profile, none }

/// Design #8 "Glass / Depth" — a **floating frosted-glass** bottom bar: rounded,
/// blurred, lifted off the page with a soft shadow. The active tab shows its
/// icon inside an indigo-gradient rounded-square chip with an indigo label;
/// inactive tabs are a muted icon + label. Tab switches use `context.go` so each
/// destination is a clean stack root.
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key, required this.current});

  /// The destination this bar is rendered under (drives the selected slot).
  final MainTab current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final elevation = AppElevation.of(context);
    final reduce = reduceMotion(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isSignedIn =
            authState is Authenticated ||
            authState is PendingApproval ||
            authState is Rejected ||
            authState is Suspended;

        final highlightNone = current == MainTab.none;

        // 035 craft wave — ONE icon family (Lucide, matching the content
        // cards) and ONE metaphor per tab: selection is carried by the chip
        // treatment, not by swapping to a different glyph (the old bar turned
        // the Search magnifier into a globe when selected).
        final slots = <Widget>[
          _NavTab(
            icon: LucideIcons.house,
            label: l10n.home_title,
            selected: !highlightNone && current == MainTab.home,
            bounce: !reduce && current == MainTab.home,
            onTap: () => context.go(AppRoutes.home),
          ),
          _NavTab(
            icon: LucideIcons.search,
            label: l10n.nav_search_map,
            selected: !highlightNone && current == MainTab.search,
            bounce: !reduce && current == MainTab.search,
            onTap: () => context.go(AppRoutes.search),
          ),
          _NavTab(
            icon: LucideIcons.heart,
            label: l10n.favorites_page_title,
            selected: !highlightNone && current == MainTab.favorites,
            bounce: !reduce && current == MainTab.favorites,
            onTap: () => context.go(AppRoutes.favorites),
          ),
          _NavTab(
            icon: LucideIcons.message_circle,
            label: l10n.nav_messages,
            selected: !highlightNone && current == MainTab.chat,
            bounce: !reduce && current == MainTab.chat,
            onTap: () =>
                context.go(isSignedIn ? AppRoutes.chat : AppRoutes.login),
          ),
          _NavTab(
            icon: LucideIcons.user,
            label: l10n.profile_title,
            selected: !highlightNone && current == MainTab.profile,
            bounce: !reduce && current == MainTab.profile,
            onTap: () =>
                context.go(isSignedIn ? AppRoutes.profile : AppRoutes.login),
          ),
        ];

        return Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.lg,
            end: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: appRadius(AppRadii.xl),
                boxShadow: elevation.level2,
              ),
              child: GlassPanel(
                radius: AppRadii.xl,
                blur: 24,
                tintOpacity: 0.82,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [for (final slot in slots) Expanded(child: slot)],
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

/// A single floating-glass nav tab — the active tab wraps its icon in an
/// indigo-gradient chip; inactive tabs are a muted icon + label.
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.bounce,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool bounce;
  final VoidCallback onTap;

  static const double _iconSize = 22;
  static const double _chipW = 46;
  static const double _chipH = 32;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final gradients = AppGradients.of(context);

    Widget glyph = Icon(
      icon,
      size: _iconSize,
      color: selected ? colors.onPrimary : colors.textMuted,
    );
    if (bounce) {
      glyph = glyph.animate().scaleXY(
        begin: 0.8,
        end: 1.0,
        duration: AppMotion.slow,
        curve: Curves.easeOutBack,
      );
    }

    final iconSlot = selected
        ? Container(
            width: _chipW,
            height: _chipH,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: gradients.primaryGradient,
              borderRadius: appRadius(AppRadii.md),
            ),
            child: glyph,
          )
        : SizedBox(
            height: _chipH,
            child: Center(child: glyph),
          );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: appRadius(AppRadii.md),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            iconSlot,
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.labelSmall.copyWith(
                color: selected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
