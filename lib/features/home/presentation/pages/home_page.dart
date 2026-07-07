import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_nav_drawer.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../core/settings/listing_view_mode.dart';
import '../../../../core/widgets/ds/ds_listing_card.dart';
import '../../../../core/widgets/ds/ds_listing_card_data.dart';
import '../../../../core/widgets/ds/listing_view_mode_switcher.dart';
import '../../../../core/widgets/main_bottom_nav.dart';
import '../../../../core/widgets/publish_fab.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../core/widgets/star_refresh_indicator.dart';
import '../../../../core/widgets/theme_toggle_action.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/domain/value_objects/publisher_status.dart';
import '../../../../shared/presentation/deed_finish_labels.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../currencies/domain/usecases/list_currencies.dart';
import '../../../favorites/presentation/bloc/favorites_cubit.dart';
import '../../../inquiries/presentation/bloc/inquiries_unread_cubit.dart';
import '../../../notifications/presentation/bloc/notification_badge_cubit.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../bloc/featured_listings_cubit.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../ads/domain/entities/ad_placement.dart';
import '../../../ads/presentation/widgets/ad_slot.dart';
import '../../../recently_viewed/presentation/bloc/recently_viewed_cubit.dart';
import '../../../recently_viewed/presentation/widgets/recently_viewed_carousel.dart';
import '../../../reels/presentation/widgets/reels_rail.dart';
import '../../domain/entities/home_listing_card.dart';
import '../widgets/featured_listings_carousel.dart';
import '../widgets/hero_search_bar.dart';
import '../widgets/home_categories_section.dart';
import '../widgets/home_transaction_toggle.dart';
import '../widgets/home_trust_strip.dart';
import '../widgets/home_verified_rail.dart';
import '../widgets/map_entry_tile.dart';

/// Phase 13 — public HomePage per FR-013 + contracts/
/// phase13-home-page-composition.md.
///
/// Composes (top-to-bottom):
/// 1. AppBar with brand-mark + auth-state-branched sign-in / profile icon.
/// 2. [HeroSearchBar] (Q1=A stub).
/// 3. [PropertyTypeShortcutRow] (Q1=A stub).
/// 4. Section header `home_latest_listings_header`.
/// 5. `RefreshIndicator`-wrapped `ListView.builder` of [DsListingCard]
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
          create: (_) => getIt<FeaturedListingsCubit>()..load(locale: locale),
        ),
        // Recently-viewed: the shared (lazySingleton) cubit, loaded from local
        // storage when Home opens. .value (not create) so we don't dispose the
        // singleton the listing-details record path also uses.
        BlocProvider<RecentlyViewedCubit>.value(
          value: getIt<RecentlyViewedCubit>()..load(),
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

    // Product analytics — screen view (best-effort; no-op when telemetry off).
    getIt<AnalyticsService>().logScreen('home');

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
      // Phase 030 (W5) — app navigation drawer (opens from the start side =
      // RIGHT under RTL). Hosts the tool sections relocated off the Profile tab.
      drawer: const AppNavDrawer(),
      appBar: AppBar(
        // Phase 030 (W5) — hamburger affordance opening the nav drawer. Wrapped
        // in a Builder so Scaffold.of(context) resolves the enclosing Scaffold.
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            tooltip: l10n.navDrawerMenuTooltip,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const BrandMark(withWordmark: true, size: 30),
        actions: const [
          // Phase 33 restyle — the notification bell moves down into the photo-
          // forward header row (a 42px circular button); the bar keeps only the
          // locale/theme toggles. Profile/sign-in is the Profile tab.
          LocaleToggleAction(),
          ThemeToggleAction(),
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
                  // Capture cubits before the awaits (no BuildContext across
                  // async gaps).
                  final featured = context.read<FeaturedListingsCubit>();
                  final recent = context.read<RecentlyViewedCubit>();
                  context.read<HomeBloc>().add(
                    HomeFeedRefreshRequested(locale: locale),
                  );
                  // Featured-listings + recently-viewed also reload on refresh.
                  await featured.load(locale: locale);
                  await recent.load();
                },
                child: _buildBody(context, state, currenciesByCode, l10n),
              );
            },
          );
        },
      ),
      // Phase 035 — the publish entry is a floating Extended FAB above the
      // 5-tab bottom nav (publishers only; self-gates to nothing otherwise).
      bottomNavigationBar: const MainBottomNav(current: MainTab.home),
      floatingActionButton: const PublishFab(),
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
        // Phase 035 — the design's transaction-mode quick-filter (للبيع/للإيجار/
        // يومي); each opens Search pre-filtered by that deal type.
        const SliverToBoxAdapter(child: HomeTransactionToggle()),
        // Phase 035 (Home revamp) — the visual "التصنيفات" section (icon tiles +
        // عرض الكل) replaces the thin chip row.
        const SliverToBoxAdapter(child: HomeCategoriesSection()),
        // Phase 15 G1: Map entry tile — R-91 slot.
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
        // Phase 035 (Home revamp) — horizontal rail of field-verified listings
        // (trust signal). Hides itself when the feed has no verified listings.
        SliverToBoxAdapter(
          child: HomeVerifiedRail(
            listings: state.listings,
            currenciesByCode: currenciesByCode,
          ),
        ),
        // Recently-viewed: the "شوهد مؤخراً / Recently viewed" row, just under the
        // featured carousel. Backed by local storage; hides itself when empty.
        const SliverToBoxAdapter(child: RecentlyViewedCarousel()),
        // Phase 029 (Reels W4) — the "Reels" rail of vertical video posters.
        // Self-wired (hosts its own ReelsRailCubit) and hides itself entirely
        // on empty / failure / loading, mirroring the FeaturedListingsCarousel.
        const SliverToBoxAdapter(child: ReelsRail()),
        // Phase 035 — trust strip reinforcing the safety positioning, above the
        // main feed.
        const SliverToBoxAdapter(child: HomeTrustStrip()),
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: l10n.home_latest_listings_header,
            trailing: const ListingViewModeSwitcher(),
          ),
        ),
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
                child: _FeedCard(
                  card: card,
                  currenciesByCode: currenciesByCode,
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
/// an image block plus a price and title line, mirroring the feed card.
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
  const _SectionHeader({required this.title, this.trailing});

  final String title;

  /// Optional trailing action (e.g. the feed's [ListingViewModeSwitcher]).
  final Widget? trailing;

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
          Expanded(child: Text(title, style: styles.titleLarge)),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Phase 035 — a feed row that maps a [HomeListingCard] into the unified
/// [DsListingCard] and re-renders at the user's chosen [ListingViewMode].
class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.card, required this.currenciesByCode});

  final HomeListingCard card;
  final Map<String, Currency> currenciesByCode;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final data = _toCardData(
      card,
      currenciesByCode,
      locale,
      AppLocalizations.of(context)!,
    );
    return ValueListenableBuilder<ListingViewMode>(
      valueListenable: ListingViewModePref.notifier,
      builder: (context, mode, _) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: DsListingCard(data: data, mode: mode),
      ),
    );
  }
}

DsListingCardData _toCardData(
  HomeListingCard card,
  Map<String, Currency> byCode,
  Locale locale,
  AppLocalizations l10n,
) {
  final currency = byCode[card.primaryPrice.currencyCode];
  final priceText = currency == null
      ? '${card.primaryPrice.amount} ${card.primaryPrice.currencyCode}'
      : MoneyFormatter.format(
          Money(
            amount: card.primaryPrice.amount,
            currencyCode: card.primaryPrice.currencyCode,
          ),
          locale: locale,
          currency: currency,
        );
  final location = [
    if (card.governorateNameLocalized.isNotEmpty &&
        card.governorateNameLocalized != '—')
      card.governorateNameLocalized,
    if (card.cityNameLocalized.isNotEmpty && card.cityNameLocalized != '—')
      card.cityNameLocalized,
  ].join(' • ');
  return DsListingCardData(
    id: card.id,
    title: card.title,
    priceText: priceText,
    purpose: card.purpose,
    locationText: location.isEmpty ? '—' : location,
    imageUrl: card.mainImageUrl,
    rooms: card.rooms,
    bathrooms: card.bathrooms,
    areaSize: card.areaSize,
    isFeatured: card.isFeatured,
    agencyId: card.agencyId,
    agencyName: card.agencyName,
    agencyLogoUrl: card.agencyLogoUrl,
    publishedAt: card.publishedAt,
    isVerified: card.isVerified,
    deedLabel: card.deedType == null
        ? null
        : deedTypeLabel(l10n, card.deedType),
  );
}

/// Phase 33 restyle — the photo-forward home **header row**. A small italic
/// accent greeting (brand-primary) sits over a bold name/title line on the
/// start side, with a circular avatar + a circular notification bell on the
/// end side. Reuses the existing greeting strings, the avatar from the auth
/// profile, and the [NotificationBadgeCubit] count + routing — purely visual.
class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final profile = switch (state) {
          Authenticated(:final profile) => profile,
          _ => null,
        };
        final name = _firstName(
          profile?.fullName ?? profile?.username ?? '',
        );
        // Accent line = the localized greeting (e.g. "Hi Ahmad," / "Welcome,").
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Small italic brand-accent greeting line.
                      Text(
                        greeting,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.labelLarge.copyWith(
                          color: colors.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      // Bold ~22px subtitle line — the loudest line on first
                      // paint.
                      Text(
                        l10n.home_greeting_subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: styles.headlineMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _HomeAvatar(avatarUrl: profile?.avatarUrl),
                const SizedBox(width: AppSpacing.sm),
                const _HomeHeaderBell(),
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

/// A 46px circular avatar for the home header. Renders the user's avatar photo
/// when present, otherwise a neutral person glyph on a recessed surface.
class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar({required this.avatarUrl});

  final String? avatarUrl;

  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        shape: BoxShape.circle,
        border: Border.all(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: (avatarUrl != null && avatarUrl!.isNotEmpty)
          ? AppNetworkImage(url: avatarUrl)
          : Icon(
              Icons.person_outline,
              size: AppSpacing.xl,
              color: colors.textMuted,
            ),
    );
  }
}

/// A 42px circular notification bell for the home header — a bordered surface
/// chip with a small coral dot when there are unread notifications. Reuses the
/// shared [NotificationBadgeCubit] count and routes to /notifications on tap.
class _HomeHeaderBell extends StatelessWidget {
  const _HomeHeaderBell();

  static const double _size = 42;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return BlocProvider.value(
      value: getIt<NotificationBadgeCubit>(),
      child: BlocBuilder<NotificationBadgeCubit, NotificationBadgeState>(
        builder: (context, state) {
          return Tooltip(
            message: l10n.notification_bell_tooltip,
            child: Material(
              color: colors.surface,
              shape: CircleBorder(side: BorderSide(color: colors.outline)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(AppRoutes.notifications),
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_none_outlined,
                        size: AppSpacing.xl,
                        color: colors.onSurface,
                      ),
                      if (state.count > 0)
                        PositionedDirectional(
                          top: AppSpacing.sm,
                          end: AppSpacing.md,
                          child: Container(
                            width: AppSpacing.sm,
                            height: AppSpacing.sm,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.surface),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
        child: AppSpinner(),
      );
    }
    if (state.endReached && state.listings.isNotEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Center(
          child: Text(
            l10n.home_no_more_listings,
            style: AppTextStyles.of(context).labelMedium.copyWith(
              color: AppColors.of(context).onSurfaceVariant,
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
