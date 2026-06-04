import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/domain/value_objects/account_status.dart';
import '../../shared/domain/value_objects/publisher_status.dart';
import '../routing/app_router.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// The four primary destinations of the public app shell.
enum MainTab { home, search, favorites, profile }

/// Phase 25 (Claude Design) — the persistent bottom navigation bar shared by
/// the four primary surfaces (home / search / favorites / profile).
///
/// Replaces the Phase 13 publish [FloatingActionButton] and de-clutters the
/// Home [AppBar]: profile/sign-in becomes the Profile tab, while the
/// inquiries-inbox and admin-panel entries move into the Profile menu.
///
/// Approved publishers get a prominent accent **Publish** action in the centre
/// that pushes the create-listing form — it never becomes a selected tab. Tab
/// switches use `context.go` so each destination is a clean stack root; deep
/// pages (listing details, agency, etc.) push full-screen over the bar.
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key, required this.current});

  /// The destination this bar is rendered under (drives the selected slot).
  final MainTab current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isSignedIn =
            authState is Authenticated ||
            authState is PendingApproval ||
            authState is Rejected ||
            authState is Suspended;
        final isApprovedPublisher =
            authState is Authenticated &&
            authState.profile.accountStatus == AccountStatus.approved &&
            authState.profile.publisherStatus == PublisherStatus.approved;

        // Destinations + parallel action/tab lists so the prominent "Publish"
        // entry can sit between Search and Favorites without ever being a tab.
        final destinations = <Widget>[
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.home_title,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search_rounded),
            label: l10n.nav_search,
          ),
        ];
        final actions = <VoidCallback>[
          () => context.go(AppRoutes.home),
          () => context.go(AppRoutes.search),
        ];
        final tabs = <MainTab?>[MainTab.home, MainTab.search];

        if (isApprovedPublisher) {
          destinations.add(
            NavigationDestination(
              icon: _PublishIcon(colors: colors),
              label: l10n.nav_publish,
            ),
          );
          actions.add(
            () => context.pushNamed(AppRouteNames.publisherListingsCreate),
          );
          tabs.add(null);
        }

        destinations.addAll([
          NavigationDestination(
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: l10n.favorites_page_title,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.profile_title,
          ),
        ]);
        actions.addAll([
          () => context.go(AppRoutes.favorites),
          // Anonymous users tapping Profile are sent to sign-in instead of the
          // (auth-only) profile screen.
          () => context.go(isSignedIn ? AppRoutes.profile : AppRoutes.login),
        ]);
        tabs.addAll([MainTab.favorites, MainTab.profile]);

        var selectedIndex = tabs.indexOf(current);
        if (selectedIndex < 0) selectedIndex = 0;

        // Design-faithful: no indicator pill — primary on the selected slot,
        // muted otherwise (mirrors the Claude Design `.nav-item` / `.on`).
        return NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: colors.card,
            indicatorColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                size: AppSpacing.xl,
                color: states.contains(WidgetState.selected)
                    ? colors.primary
                    : colors.textMuted,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => styles.labelMedium.copyWith(
                color: states.contains(WidgetState.selected)
                    ? colors.primary
                    : colors.textMuted,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => actions[i](),
            destinations: destinations,
          ),
        );
      },
    );
  }
}

/// Prominent accent circle for the publishers-only "Publish" action — the
/// in-bar successor to the old publish FloatingActionButton.
class _PublishIcon extends StatelessWidget {
  const _PublishIcon({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
      child: Icon(Icons.add_rounded, color: colors.onAccent),
    );
  }
}
