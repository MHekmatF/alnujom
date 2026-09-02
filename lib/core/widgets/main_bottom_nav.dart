import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../routing/app_router.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';
import 'guest_sign_in_sheet.dart';

/// The primary destinations of the public app shell.
///
/// 5-tab IA — Home · Search+Map · Saved · Messages · Account. The "أضف عقار"
/// publish action is a floating [PublishFab], not a bar slot.
enum MainTab { home, search, favorites, chat, profile, none }

/// DC "Blue Crown" — a **standard Material bottom bar**: a full-width white
/// surface flush to the bottom edge with a 1px top hairline (no glass, no
/// blur, no floating pill). The selected tab shows its filled icon inside a
/// tinted pill (`secondaryContainer`); unselected tabs are a muted outline
/// icon + label. Tab switches use `context.go` so each destination is a clean
/// stack root.
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key, required this.current});

  /// The destination this bar is rendered under (drives the selected slot).
  final MainTab current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isSignedIn =
            authState is Authenticated ||
            authState is PendingApproval ||
            authState is Rejected ||
            authState is Suspended;

        final none = current == MainTab.none;

        final slots = <Widget>[
          _NavTab(
            iconOutline: Icons.home_outlined,
            iconFilled: Icons.home,
            label: l10n.home_title,
            selected: !none && current == MainTab.home,
            onTap: () => context.go(AppRoutes.home),
          ),
          _NavTab(
            iconOutline: Icons.search,
            iconFilled: Icons.search,
            label: l10n.nav_search_map,
            selected: !none && current == MainTab.search,
            onTap: () => context.go(AppRoutes.search),
          ),
          // The three account tabs. A guest tapping one used to be sent to
          // /login with `context.go`, which replaces the whole stack — so they
          // lost their place, got no explanation, and Back quit the app
          // outright (device walk 2026-09-02: three of five tabs were a
          // one-way exit). They now get a sheet over the page they were
          // already on, and dismissing it puts them straight back.
          _NavTab(
            iconOutline: Icons.bookmark_border,
            iconFilled: Icons.bookmark,
            label: l10n.favorites_page_title,
            selected: !none && current == MainTab.favorites,
            onTap: () => isSignedIn
                ? context.go(AppRoutes.favorites)
                : showGuestSignInSheet(context, gate: GuestGate.favorites),
          ),
          _NavTab(
            iconOutline: Icons.forum_outlined,
            iconFilled: Icons.forum,
            label: l10n.nav_messages,
            selected: !none && current == MainTab.chat,
            onTap: () => isSignedIn
                ? context.go(AppRoutes.chat)
                : showGuestSignInSheet(context, gate: GuestGate.messages),
          ),
          _NavTab(
            iconOutline: Icons.person_outline,
            iconFilled: Icons.person,
            label: l10n.profile_title,
            selected: !none && current == MainTab.profile,
            onTap: () => isSignedIn
                ? context.go(AppRoutes.profile)
                : showGuestSignInSheet(context, gate: GuestGate.profile),
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
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Row(
                children: [for (final slot in slots) Expanded(child: slot)],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A single DC nav tab — selected wraps a filled icon in a tinted pill; the
/// unselected state is a muted outline icon.
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.iconOutline,
    required this.iconFilled,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData iconOutline;
  final IconData iconFilled;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double _iconSize = 23;
  static const double _pillW = 62;
  static const double _pillH = 32;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final iconSlot = selected
        ? Container(
            width: _pillW,
            height: _pillH,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: appRadius(AppRadii.pill),
            ),
            child: Icon(
              iconFilled,
              size: _iconSize,
              color: colors.onSecondaryContainer,
            ),
          )
        : SizedBox(
            height: _pillH,
            child: Center(
              child: Icon(iconOutline, size: _iconSize, color: colors.textMuted),
            ),
          );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: appRadius(AppRadii.pill),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconSlot,
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.labelSmall.copyWith(
                color: selected ? colors.onSurface : colors.textMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
