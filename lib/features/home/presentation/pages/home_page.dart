import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import '../../../../core/widgets/crown_underline_tabs.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/guest_sign_in_sheet.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/settings/listing_view_mode.dart';
import '../../../../core/widgets/ds/ds_listing_card.dart';
import '../../../../core/widgets/main_bottom_nav.dart';
import '../../../../core/widgets/publish_fab.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../core/widgets/star_refresh_indicator.dart';
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
import '../../../recently_viewed/presentation/bloc/recently_viewed_cubit.dart';
import '../../../search/domain/entities/filter_state.dart';
import '../../domain/entities/home_listing_card.dart';
import '../widgets/featured_listings_carousel.dart';
import '../widgets/home_card_mapper.dart';
import '../widgets/home_city_picker_sheet.dart';

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

  /// DC for-sale / rent / daily-rent segmented control selection.
  int _segment = 0;

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

    final colors = AppColors.of(context);
    // DC "Blue Crown" — light status-bar icons over the deep-blue crown that
    // sits at the top of the Home scroll.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: colors.card,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        // PERF-H1: the feed is now a virtualized sliver list outside the white
        // sheet Container, so the scaffold itself carries the sheet's `card`
        // colour — this makes the 18px crown/sheet overlap read seamlessly and
        // gives the feed rows their card background.
        backgroundColor: colors.card,
        drawer: const AppNavDrawer(),
        body: FutureBuilder<List<Currency>>(
          future: _currenciesFuture,
          builder: (context, currencySnap) {
            final currenciesByCode = <String, Currency>{
              for (final c in currencySnap.data ?? const <Currency>[])
                c.code: c,
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
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HomeState state,
    Map<String, Currency> currenciesByCode,
    AppLocalizations l10n,
  ) {
    final colors = AppColors.of(context);
    // DC "Blue Crown" — the deep-blue crown scrolls at the top; a white sheet
    // with rounded top corners overlaps it by 18px (the scaffold bg is `card` so
    // the overlap reads seamlessly), carrying the category grid, featured rail,
    // ad and section header. PERF-H1: the feed below is now a virtualized
    // SliverList.builder — the old Column kept every paged card + image alive.
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _HomeCrown(
            selectedPurpose: _segment,
            onPurposeChanged: (i) => setState(() => _segment = i),
          ),
        ),
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -18),
            child: Container(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: const BorderRadiusDirectional.vertical(
                  top: Radius.circular(AppRadii.sheet),
                ),
              ),
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HomeCategoryGrid(
                    onSelected: (_) => context.go(AppRoutes.search),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FeaturedListingsCarousel(currenciesByCode: currenciesByCode),
                  // DC: the sponsored slot sits between the featured rail and
                  // the "latest" feed (renders nothing when no ad is served).
                  const Padding(
                    padding: EdgeInsetsDirectional.only(top: AppSpacing.sm),
                    child: AdSlot(placement: AdPlacement.homeMiddleBanner),
                  ),
                  _DcSectionHeader(
                    title: l10n.home_latest_listings_header,
                    onSeeAll: () => context.go(AppRoutes.search),
                  ),
                ],
              ),
            ),
          ),
        ),
        ..._feedSlivers(context, state, currenciesByCode, l10n),
      ],
    );
  }

  List<Widget> _feedSlivers(
    BuildContext context,
    HomeState state,
    Map<String, Currency> currenciesByCode,
    AppLocalizations l10n,
  ) {
    switch (state.status) {
      case HomeFeedStatus.initial:
      case HomeFeedStatus.loading:
        return [
          SliverToBoxAdapter(
            child: Column(
              children: List.generate(3, (_) => const _HomeCardSkeleton()),
            ),
          ),
        ];
      case HomeFeedStatus.error:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              child: ErrorState(
                title: l10n.error_could_not_load_listings,
                variant: ErrorStateVariant.network,
                onRetry: () => context.read<HomeBloc>().add(
                  HomeFeedLoadRequested(
                    locale: Localizations.localeOf(context),
                  ),
                ),
              ),
            ),
          ),
        ];
      case HomeFeedStatus.success:
      case HomeFeedStatus.loadingMore:
      case HomeFeedStatus.refreshing:
        if (state.listings.isEmpty && state.status == HomeFeedStatus.success) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
                child: _EmptyView(l10n: l10n),
              ),
            ),
          ];
        }
        return [
          SliverList.builder(
            itemCount: state.listings.length,
            itemBuilder: (context, index) => StaggeredListItem(
              index: index,
              enabled: state.status != HomeFeedStatus.refreshing,
              child: _FeedCard(
                card: state.listings[index],
                currenciesByCode: currenciesByCode,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _FeedFooter(state: state, l10n: l10n),
          ),
          // Clearance so the floating publish FAB never covers the last card.
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xxxl + AppSpacing.xl),
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

/// Phase 035 — a feed row that maps a [HomeListingCard] into the unified
/// [DsListingCard] and re-renders at the user's chosen [ListingViewMode].
class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.card, required this.currenciesByCode});

  final HomeListingCard card;
  final Map<String, Currency> currenciesByCode;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final data = homeCardToData(
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

/// Phase 33 restyle — the photo-forward home **header row**. A small italic
/// accent greeting (brand-primary) sits over a bold name/title line on the
/// start side, with a circular avatar + a circular notification bell on the
/// end side. Reuses the existing greeting strings, the avatar from the auth
/// profile, and the [NotificationBadgeCubit] count + routing — purely visual.
/// DC "Blue Crown" — the deep-blue brand header at the top of Home: the star
/// logo + brand, chat + notification actions, a city selector, and a white
/// search field. It scrolls with the content; the white sheet below overlaps
/// it by 18px so the blue peeks through the sheet's rounded top corners.
class _HomeCrown extends StatelessWidget {
  const _HomeCrown({
    required this.selectedPurpose,
    required this.onPurposeChanged,
  });

  /// للبيع / للإيجار / إيجار يومي — the DC purpose tabs now live in the crown.
  final int selectedPurpose;
  final ValueChanged<int> onPurposeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      color: colors.brandHeader,
      // Bottom padding is tighter than before: the purpose tabs now sit at the
      // crown's bottom edge and the white sheet overlaps it, so a smaller pad
      // keeps the selected tab's underline clear of the sheet.
      padding: EdgeInsetsDirectional.only(
        top: topInset + AppSpacing.sm,
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        bottom: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Opens the app navigation drawer (Dashboard / Admin / Messages /
              // …). Without it the drawer is edge-swipe-only and undiscoverable.
              Builder(
                builder: (context) => _CrownAction(
                  icon: Icons.menu,
                  onTap: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 33,
                height: 33,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.onBrandHeader,
                  borderRadius: appRadius(AppRadii.sm),
                ),
                child: Icon(Icons.star, size: 22, color: colors.brandHeader),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.home_app_bar_title,
                style: styles.titleLarge.copyWith(
                  color: colors.onBrandHeader,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Both of these are account-only. A guest tapping the message
              // icon used to be thrown to /login by the global redirect — and
              // because this used `go`, Back then quit the app. The bell at
              // least pushed, but still landed a signed-out visitor on a login
              // form with no idea why. Ask, in place, instead.
              _CrownAction(
                icon: Icons.chat_bubble_outline,
                onTap: () => context.read<AuthBloc>().state is Authenticated
                    ? context.go(AppRoutes.chat)
                    : showGuestSignInSheet(context, gate: GuestGate.messages),
              ),
              _CrownNotificationAction(
                onTap: () => context.read<AuthBloc>().state is Authenticated
                    ? context.push(AppRoutes.notifications)
                    : showGuestSignInSheet(
                        context,
                        gate: GuestGate.notifications,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () async {
              final govId = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => const HomeCityPickerSheet(),
              );
              if (govId != null && context.mounted) {
                context.go(
                  AppRoutes.search,
                  extra: FilterState(governorateId: govId),
                );
              }
            },
            borderRadius: appRadius(AppRadii.sm),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: colors.onBrandHeader,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.home_crown_location,
                    style: styles.bodyMedium.copyWith(
                      color: colors.onBrandHeader,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.expand_more,
                    size: 20,
                    color: colors.onBrandHeader,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: colors.brandHeaderField,
            borderRadius: appRadius(AppRadii.md),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go(AppRoutes.search),
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 22,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.home_search_bar_placeholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.bodyMedium.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(width: 1, height: 22, color: colors.outline),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.tune, size: 23, color: colors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CrownUnderlineTabs(
            labels: [
              l10n.listingPurposeSale,
              l10n.listingPurposeRent,
              l10n.listingPurposeDailyRent,
            ],
            selectedIndex: selectedPurpose,
            onChanged: onPurposeChanged,
          ),
        ],
      ),
    );
  }
}

/// A 42px circular action button on the blue crown (white icon).
class _CrownAction extends StatelessWidget {
  const _CrownAction({required this.icon, required this.onTap, this.badge});

  final IconData icon;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 24, color: colors.onBrandHeader),
            if (badge != null)
              PositionedDirectional(top: 5, end: 5, child: badge!),
          ],
        ),
      ),
    );
  }
}

/// The crown's notification bell with the live unread count badge.
class _CrownNotificationAction extends StatelessWidget {
  const _CrownNotificationAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<NotificationBadgeCubit>(),
      child: BlocBuilder<NotificationBadgeCubit, NotificationBadgeState>(
        builder: (context, state) {
          return _CrownAction(
            icon: Icons.notifications_none,
            onTap: onTap,
            badge: state.count > 0 ? _CountBadge(count: state.count) : null,
          );
        },
      ),
    );
  }
}

/// A small red count badge (crown actions + chat).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.error,
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: colors.brandHeader, width: 1.5),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: styles.labelSmall.copyWith(
          color: colors.onError,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// DC category grid — 8 property-type tiles in a 4-column layout, each a tonal
/// rounded square with its icon and label. Tapping routes to search.
class _HomeCategoryGrid extends StatelessWidget {
  const _HomeCategoryGrid({required this.onSelected});

  final void Function(int index) onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cats = <(IconData, String)>[
      (Icons.apartment, l10n.propertyTypeApartment),
      (Icons.villa, l10n.propertyTypeVilla),
      (Icons.landscape, l10n.propertyTypeLand),
      (Icons.storefront, l10n.propertyTypeShop),
      (Icons.business_center, l10n.propertyTypeOffice),
      (Icons.agriculture, l10n.propertyTypeFarm),
      (Icons.warehouse, l10n.propertyTypeWarehouse),
      (Icons.grid_view, l10n.propertyTypeOther),
    ];
    Widget row(int start) => Row(
      children: [
        for (var i = start; i < start + 4; i++)
          Expanded(
            child: _CategoryTile(
              icon: cats[i].$1,
              label: cats[i].$2,
              onTap: () => onSelected(i),
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: [
          row(0),
          const SizedBox(height: AppSpacing.xs),
          row(4),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: appRadius(AppRadii.md),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: appRadius(AppRadii.lg),
              ),
              child: Icon(icon, size: 27, color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.labelMedium.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DC section header — a bold title with a trailing "see all" text button.
class _DcSectionHeader extends StatelessWidget {
  const _DcSectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          Expanded(
            child: Text(
              title,
              style: styles.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              child: Text(
                l10n.home_see_all,
                style: styles.labelLarge.copyWith(color: colors.primary),
              ),
            ),
        ],
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

        // Three different people land here, and until 2026-09-02 two of them
        // got the same wrong answer: "sign in to publish", pointing at /login
        // via `context.go`. For a guest that wiped the stack — Back then quit
        // the app. For a signed-in user who simply is not an approved
        // publisher yet it was worse than useless: they ARE signed in, so the
        // redirect bounced them straight back and the button did nothing at
        // all. Each case now gets the step that is actually next for them.
        final isGuest = profile == null;

        return EmptyState(
          icon: Icons.home_outlined,
          headline: l10n.home_no_listings_yet,
          ctaLabel: isApprovedPublisher
              ? l10n.home_empty_publish_first_listing
              : isGuest
              ? l10n.home_empty_sign_in_to_publish
              : l10n.home_empty_get_approved_to_publish,
          onCtaPressed: isApprovedPublisher
              ? () => context.pushNamed(AppRouteNames.publisherListingsCreate)
              : isGuest
              ? () => showGuestSignInSheet(context, gate: GuestGate.publish)
              : () => context.pushNamed(AppRouteNames.publisherApprovalPending),
        );
      },
    );
  }
}
