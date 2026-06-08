import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../core/widgets/main_bottom_nav.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../core/widgets/star_refresh_indicator.dart';
import '../../../../core/widgets/theme_toggle_action.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
import '../../../../shared/domain/value_objects/publisher_status.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../currencies/domain/usecases/list_currencies.dart';
import '../../../favorites/presentation/bloc/favorites_cubit.dart';
import '../../../inquiries/presentation/bloc/inquiries_unread_cubit.dart';
import '../../../notifications/presentation/bloc/notification_badge_cubit.dart';
import '../bloc/featured_listings_cubit.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../ads/domain/entities/ad_placement.dart';
import '../../../ads/presentation/widgets/ad_slot.dart';
import '../widgets/featured_listings_carousel.dart';
import '../widgets/hero_search_bar.dart';
import '../widgets/home_listing_card.dart';
import '../../../notifications/presentation/widgets/notification_bell_action.dart';
import '../widgets/map_entry_tile.dart';
import '../widgets/property_type_shortcut_row.dart';

/// Phase 13 — public HomePage per FR-013 + contracts/
/// phase13-home-page-composition.md.
///
/// Composes (top-to-bottom):
/// 1. AppBar with brand-mark + auth-state-branched sign-in / profile icon.
/// 2. [HeroSearchBar] (Q1=A stub).
/// 3. [PropertyTypeShortcutRow] (Q1=A stub).
/// 4. Section header `home_latest_listings_header`.
/// 5. `RefreshIndicator`-wrapped `ListView.builder` of [HomeListingCardTile]
///    widgets, driven by [HomeBloc]. Cursor pagination + infinite scroll.
///
/// Empty-state CTA branches on auth state per FR-019:
/// - approved publisher → "Publish your first listing" → Phase 10 form
/// - anonymous OR non-publisher → "Sign in to publish" → Phase 5 login
///
/// Replaces the Phase 5 placeholder HomePage. The `/` route is rewired to
/// this page by Phase 13 Sub-Phase F (T039).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>(
          create: (_) =>
              getIt<HomeBloc>()..add(HomeFeedLoadRequested(locale: locale)),
        ),
        // Featured-listings treatment — load the "✨ عقارات مميّزة" carousel when
        // Home opens. Page-scoped (mirrors HomeBloc); the section hides itself
        // on empty / failure.
        BlocProvider<FeaturedListingsCubit>(
          create: (_) =>
              getIt<FeaturedListingsCubit>()..load(locale: locale),
        ),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  late final ScrollController _scrollController;
  late final Future<List<Currency>> _currenciesFuture;
  AppLifecycleListener? _lifecycleListener;

  /// Threshold (in pixels) from the bottom that triggers
  /// `HomeFeedNextPageRequested` per FR-016. Approximately 5 cards' worth.
  static const double _nextPageThreshold = 1200;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _currenciesFuture = getIt<ListCurrencies>().call(activeOnly: false);

    // Phase 17: instantiate FavoritesCubit so its AuthBloc subscription
    // hydrates the session favorited-id set on first signed-in build
    // (mirrors Phase 16 InquiriesUnreadCubit touch; no AppLifecycleListener
    // needed — favorites state is auth-driven, not time-driven).
    getIt<FavoritesCubit>();

    // Phase 16 FR-019a: refresh unread inquiry count on cold launch and on
    // every app foreground-resume (AppLifecycleState.resumed).
    getIt<InquiriesUnreadCubit>().refresh();
    // Phase 22 R-193: refresh notification badge on cold launch + resume.
    getIt<NotificationBadgeCubit>().refresh();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        getIt<InquiriesUnreadCubit>().refresh();
        // Phase 22 R-193: badge refresh on foreground-resume (NOT Realtime).
        getIt<NotificationBadgeCubit>().refresh();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _nextPageThreshold) {
      final bloc = context.read<HomeBloc>();
      final locale = Localizations.localeOf(context);
      bloc.add(HomeFeedNextPageRequested(locale: locale));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(withWordmark: true, size: 30),
        actions: const [
          // Phase 25 — slimmed Home chrome: only locale/theme + notifications
          // remain in the bar. Profile/sign-in is now the Profile tab, and the
          // inquiries-inbox + admin-panel entries moved into the Profile menu.
          LocaleToggleAction(),
          ThemeToggleAction(),
          NotificationBellAction(),
        ],
      ),
      body: FutureBuilder<List<Currency>>(
        future: _currenciesFuture,
        builder: (context, currencySnap) {
          final currenciesByCode = <String, Currency>{
            for (final c in currencySnap.data ?? const <Currency>[]) c.code: c,
          };
          return BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              return StarRefreshIndicator(
                onRefresh: () async {
                  context.read<HomeBloc>().add(
                    HomeFeedRefreshRequested(locale: locale),
                  );
                  // Featured-listings treatment — pull-to-refresh also reloads
                  // the "✨ عقارات مميّزة" carousel.
                  await context.read<FeaturedListingsCubit>().load(locale: locale);
                },
                child: _buildBody(context, state, currenciesByCode, l10n),
              );
            },
          );
        },
      ),
      // Phase 25 — the publish entry now lives in the persistent bottom nav
      // (a prominent accent action for approved publishers) instead of a
      // floating action button.
      bottomNavigationBar: const MainBottomNav(current: MainTab.home),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HomeState state,
    Map<String, Currency> currenciesByCode,
    AppLocalizations l10n,
  ) {
    // Always render the static chrome (search + chips + header) so the user
    // sees something during the initial load + during refresh.
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Phase 25 (Claude Design) — personalized welcome above the search bar.
        const SliverToBoxAdapter(child: _HomeGreeting()),
        const SliverToBoxAdapter(child: HeroSearchBar()),
        const SliverToBoxAdapter(child: PropertyTypeShortcutRow()),
        // Phase 15 G1: Map entry tile — R-91 slot (between shortcut row and header).
        const SliverToBoxAdapter(child: MapEntryTile()),
        // Phase 21: home top banner (collapses to zero height when no ads — FR-012).
        const SliverToBoxAdapter(
          child: AdSlot(placement: AdPlacement.homeTopBanner),
        ),
        // Featured-listings treatment — the "✨ عقارات مميّزة" carousel sits at the
        // TOP of the feed (above the regular list). Hides itself entirely when
        // there are no active featured listings or the load failed.
        SliverToBoxAdapter(
          child: FeaturedListingsCarousel(currenciesByCode: currenciesByCode),
        ),
        SliverToBoxAdapter(child: _SectionHeader(title: l10n.home_latest_listings_header)),
        ..._buildFeedSlivers(context, state, currenciesByCode, l10n),
      ],
    );
  }

  List<Widget> _buildFeedSlivers(
    BuildContext context,
    HomeState state,
    Map<String, Currency> currenciesByCode,
    AppLocalizations l10n,
  ) {
    switch (state.status) {
      case HomeFeedStatus.initial:
      case HomeFeedStatus.loading:
        // Phase polish — card-shaped shimmer skeletons instead of a bare
        // spinner, so the feed's shape is visible while it loads.
        return [
          SliverList.builder(
            itemCount: 4,
            itemBuilder: (_, __) => const _HomeCardSkeleton(),
          ),
        ];
      case HomeFeedStatus.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(
              title: l10n.error_could_not_load_listings,
              variant: ErrorStateVariant.network,
              onRetry: () => context.read<HomeBloc>().add(
                HomeFeedLoadRequested(locale: Localizations.localeOf(context)),
              ),
            ),
          ),
        ];
      case HomeFeedStatus.success:
      case HomeFeedStatus.loadingMore:
      case HomeFeedStatus.refreshing:
        if (state.listings.isEmpty && state.status == HomeFeedStatus.success) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyView(l10n: l10n),
            ),
          ];
        }
        return [
          SliverList.separated(
            itemCount: state.listings.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final card = state.listings[index];
              return StaggeredListItem(
                index: index,
                // Don't replay the entrance cascade on a pull-to-refresh
                // rebuild; first load + appended pages still animate.
                enabled: state.status != HomeFeedStatus.refreshing,
                child: HomeListingCardTile(
                  card: card,
                  currenciesByCode: currenciesByCode,
                  displayCurrencyCode: null,
                ),
              );
            },
          ),
          // Phase 21: home middle banner — once after the first feed page
          // (R-176; not repeated on scroll).
          const SliverToBoxAdapter(
            child: AdSlot(placement: AdPlacement.homeMiddleBanner),
          ),
          SliverToBoxAdapter(
            child: _FeedFooter(state: state, l10n: l10n),
          ),
        ];
    }
  }
}

/// Card-shaped shimmer placeholder shown while the first feed page loads —
/// an image block plus a price and title line, mirroring [HomeListingCardTile].
class _HomeCardSkeleton extends StatelessWidget {
  const _HomeCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoadingState.card(),
          SizedBox(height: AppSpacing.md),
          SizedBox(height: AppSpacing.lg, child: LoadingState.row()),
          SizedBox(height: AppSpacing.sm),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 0.65,
            child: SizedBox(height: AppSpacing.lg, child: LoadingState.row()),
          ),
        ],
      ),
    );
  }
}

/// Premium feed section header — a bold title preceded by a short accent rule
/// so the "Latest listings" block reads as a deliberate section start rather
/// than a stray line of text. Purely presentational.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Short brand-accent rule anchoring the section start.
          Container(
            width: AppSpacing.xs,
            height: AppSpacing.xl,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: appRadius(AppRadii.pill),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(title, style: styles.titleLarge),
          ),
        ],
      ),
    );
  }
}

/// Phase 25 (Claude Design) — personalized home hero greeting. Renders the
/// signed-in user's first name when available, otherwise an anonymous welcome,
/// with a fixed subtitle. Purely presentational (no navigation/logic).
class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = switch (state) {
          Authenticated(:final profile) => _firstName(
            profile.fullName ?? profile.username ?? '',
          ),
          _ => null,
        };
        final greeting = (name != null && name.isNotEmpty)
            ? l10n.home_greeting_named(name)
            : l10n.home_greeting_welcome;

        return StaggeredListItem(
          index: 0,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bold display-scale welcome — the loudest line on first paint.
                Text(greeting, style: styles.displayMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.home_greeting_subtitle,
                  style: styles.bodyLarge.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// First whitespace-delimited token of a display name (the design shows just
  /// the given name); null/empty when there's nothing to show.
  static String? _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.state, required this.l10n});

  final HomeState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (state.status == HomeFeedStatus.loadingMore) {
      return const Padding(
        padding: EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.endReached && state.listings.isNotEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Center(
          child: Text(
            l10n.home_no_more_listings,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final profile = switch (authState) {
          Authenticated(:final profile) => profile,
          _ => null,
        };
        final isApprovedPublisher =
            profile != null &&
            profile.accountStatus == AccountStatus.approved &&
            profile.publisherStatus == PublisherStatus.approved;

        return EmptyState(
          icon: Icons.home_outlined,
          headline: l10n.home_no_listings_yet,
          ctaLabel: isApprovedPublisher
              ? l10n.home_empty_publish_first_listing
              : l10n.home_empty_sign_in_to_publish,
          onCtaPressed: isApprovedPublisher
              ? () => context.pushNamed(AppRouteNames.publisherListingsCreate)
              : () => context.go(AppRoutes.login),
        );
      },
    );
  }
}

