import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
import '../../../../shared/domain/value_objects/publisher_status.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../currencies/domain/usecases/list_currencies.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/hero_search_bar.dart';
import '../widgets/home_listing_card.dart';
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
/// Replaces the Phase 5 placeholder HomePage. The `/` route is rewired from
/// `ShellHomePage` to this page by Phase 13 Sub-Phase F (T039).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return BlocProvider<HomeBloc>(
      create: (_) => getIt<HomeBloc>()
        ..add(HomeFeedLoadRequested(locale: locale)),
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

  /// Threshold (in pixels) from the bottom that triggers
  /// `HomeFeedNextPageRequested` per FR-016. Approximately 5 cards' worth.
  static const double _nextPageThreshold = 1200;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _currenciesFuture = getIt<ListCurrencies>().call(activeOnly: false);
  }

  @override
  void dispose() {
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
        title: Text(l10n.home_app_bar_title),
        actions: [
          BlocSelector<AuthBloc, AuthState, bool>(
            selector: (state) => state is Authenticated ||
                state is PendingApproval ||
                state is Rejected ||
                state is Suspended,
            builder: (context, isSignedIn) {
              return IconButton(
                tooltip: l10n.home_sign_in_icon_tooltip,
                icon: Icon(
                  isSignedIn
                      ? Icons.account_circle_outlined
                      : Icons.login_outlined,
                ),
                onPressed: () {
                  if (isSignedIn) {
                    context.push(AppRoutes.profile);
                  } else {
                    context.go(AppRoutes.login);
                  }
                },
              );
            },
          ),
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
              return RefreshIndicator(
                onRefresh: () async {
                  context
                      .read<HomeBloc>()
                      .add(HomeFeedRefreshRequested(locale: locale));
                },
                child: _buildBody(context, state, currenciesByCode, l10n),
              );
            },
          );
        },
      ),
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
        const SliverToBoxAdapter(child: HeroSearchBar()),
        const SliverToBoxAdapter(child: PropertyTypeShortcutRow()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.home_latest_listings_header,
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
        return [
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case HomeFeedStatus.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ErrorView(
              message: l10n.error_could_not_load_listings,
              retryLabel: l10n.action_retry,
              onRetry: () => context.read<HomeBloc>().add(
                    HomeFeedLoadRequested(
                      locale: Localizations.localeOf(context),
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
              return HomeListingCardTile(
                card: card,
                currenciesByCode: currenciesByCode,
                displayCurrencyCode: null,
              );
            },
          ),
          SliverToBoxAdapter(
            child: _FeedFooter(state: state, l10n: l10n),
          ),
        ];
    }
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
    final theme = Theme.of(context);
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final profile = switch (authState) {
          Authenticated(:final profile) => profile,
          _ => null,
        };
        final isApprovedPublisher = profile != null &&
            profile.accountStatus == AccountStatus.approved &&
            profile.publisherStatus == PublisherStatus.approved;

        return Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.home_no_listings_yet,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isApprovedPublisher)
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_home_outlined),
                  label: Text(l10n.home_empty_publish_first_listing),
                  onPressed: () => context.pushNamed(
                    AppRouteNames.publisherListingsCreate,
                  ),
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.login_outlined),
                  label: Text(l10n.home_empty_sign_in_to_publish),
                  onPressed: () => context.go(AppRoutes.login),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}
