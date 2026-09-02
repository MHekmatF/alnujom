import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/main_bottom_nav.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/reels_feed_cubit.dart';
import 'reels_feed_page.dart';

/// Phase 030 (W4) — the Reels bottom-nav tab (it replaced the Search tab).
///
/// ⚠ NOTHING REACHES THIS PAGE TODAY. Phase 035 rebuilt the bottom bar around
/// Home · Search+Map · Saved · Messages · Account, and Reels lost its slot;
/// [ReelsRail], the other way in, is not rendered on any screen either. The
/// route still resolves, so a deep link works, but there is no tap that gets
/// here. Deliberately left that way for now: `listing_media` holds zero rows of
/// kind `video`, so surfacing it would only show every user an empty feed.
/// Give it an entry point when there is something to watch — see
/// `docs/qa/2026-09-02-device-walk.md`.
///
/// Designed to be reached via `context.go(AppRoutes.reels)`, so it sits as a
/// clean stack root with the persistent bottom navigation bar. Hosts its OWN
/// [ReelsFeedCubit] (page-scoped [BlocProvider]) and loads the first page on
/// mount — unlike the pushed [ReelsFeedPage], it never receives a rail seed.
///
/// The feed itself is the shared [ReelsFeedBody], which owns the vertical
/// [PageView] and the ≤3 [VideoPlayerController] window, disposing them when
/// the tab is left (and pausing the current one on `deactivate`). Because the
/// tab is always reachable now (the rail self-hid on empty), it shows a
/// friendly empty subtitle when there are no reels.
class ReelsTabPage extends StatelessWidget {
  const ReelsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    return Scaffold(
      body: BlocProvider<ReelsFeedCubit>(
        create: (_) => getIt<ReelsFeedCubit>()..loadInitial(locale: locale),
        child: ReelsFeedBody(emptyBody: l10n.reels_tab_empty_subtitle),
      ),
      bottomNavigationBar: const MainBottomNav(current: MainTab.none),
    );
  }
}
