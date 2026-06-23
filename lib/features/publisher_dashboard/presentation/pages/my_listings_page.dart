import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../currencies/domain/usecases/list_currencies.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../../listing_form/domain/entities/listing_revision.dart';
import '../../../listing_form/domain/usecases/find_open_revision.dart';
import '../../../locations/domain/entities/area.dart';
import '../../../locations/domain/entities/governorate.dart';
import '../../../locations/domain/repositories/locations_repository.dart';
import '../../domain/entities/moderation_history_entry.dart';
import '../../domain/entities/publisher_listing.dart';
import '../../domain/usecases/load_most_recent_rejection.dart';
import '../bloc/my_listings_bloc.dart';
import '../bloc/my_listings_event.dart';
import '../bloc/my_listings_state.dart';
import '../widgets/listing_card.dart';
import '../widgets/rejection_reason_banner.dart';
import '../widgets/status_filter_chip_row.dart';

class MyListingsPage extends StatelessWidget {
  const MyListingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MyListingsBloc>(
      create: (_) => getIt<MyListingsBloc>()..add(const LoadMyListings()),
      child: const _MyListingsView(),
    );
  }
}

class _MyListingsView extends StatefulWidget {
  const _MyListingsView();

  @override
  State<_MyListingsView> createState() => _MyListingsViewState();
}

class _MyListingsViewState extends State<_MyListingsView> {
  late final Future<List<Currency>> _currenciesFuture;

  // Last-seen one-shot renew tokens, so the BlocListener can tell whether the
  // success or the error token advanced and show the matching snackbar.
  int _lastRenewSuccessToken = 0;
  int _lastRenewErrorToken = 0;

  @override
  void initState() {
    super.initState();
    _currenciesFuture = getIt<ListCurrencies>().call(activeOnly: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myListingsPageTitle)),
      body: FutureBuilder<List<Currency>>(
        future: _currenciesFuture,
        builder: (context, currencySnap) {
          final currenciesByCode = <String, Currency>{
            for (final c in currencySnap.data ?? const <Currency>[]) c.code: c,
          };
          return Column(
            children: [
              const StatusFilterChipRow(),
              Expanded(
                child: BlocListener<MyListingsBloc, MyListingsState>(
                  listenWhen: (prev, curr) =>
                      prev.renewSuccessToken != curr.renewSuccessToken ||
                      prev.renewErrorToken != curr.renewErrorToken,
                  listener: (context, state) {
                    final succeeded =
                        state.renewSuccessToken != _lastRenewSuccessToken;
                    final failed =
                        state.renewErrorToken != _lastRenewErrorToken;
                    _lastRenewSuccessToken = state.renewSuccessToken;
                    _lastRenewErrorToken = state.renewErrorToken;
                    if (!succeeded && !failed) return;
                    AppToast.show(
                      context,
                      succeeded
                          ? l10n.myListingsRenewSuccess
                          : l10n.myListingsRenewError,
                      variant: succeeded
                          ? AppToastVariant.success
                          : AppToastVariant.error,
                    );
                  },
                  child: BlocBuilder<MyListingsBloc, MyListingsState>(
                    builder: (context, state) {
                      if (state.loading && state.listings.isEmpty) {
                        return const AppSpinner.page();
                      }
                      if (state.errorMessage != null &&
                          state.listings.isEmpty) {
                        return _ErrorBody(message: state.errorMessage!);
                      }
                      if (state.listings.isEmpty) {
                        return const _EmptyBody();
                      }
                      return _LocationLabelsHost(
                        listings: state.listings,
                        builder: (context, governorates, areas) {
                          return RefreshIndicator(
                            onRefresh: () async {
                              context.read<MyListingsBloc>().add(
                                const Refresh(),
                              );
                              await _waitForRefresh(context);
                            },
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount:
                                  state.listings.length +
                                  (state.endReached ? 0 : 1),
                              itemBuilder: (context, index) {
                                if (index >= state.listings.length) {
                                  context.read<MyListingsBloc>().add(
                                    const LoadMore(),
                                  );
                                  return const Padding(
                                    padding: EdgeInsetsDirectional.all(
                                      AppSpacing.lg,
                                    ),
                                    child: AppSpinner(),
                                  );
                                }
                                final pl = state.listings[index];
                                return _ListingRow(
                                  publisherListing: pl,
                                  currenciesByCode: currenciesByCode,
                                  governoratesById: governorates,
                                  areasById: areas,
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _waitForRefresh(BuildContext context) async {
    // Wait until the bloc's refreshing flag flips back to false.
    final bloc = context.read<MyListingsBloc>();
    await bloc.stream.firstWhere((s) => !s.refreshing);
  }
}

/// Resolves `governorate_id` / `area_id` references from the current page of
/// listings into bilingual entities, caching across refreshes so the same
/// governorate is fetched only once per session. The view exposes only IDs;
/// the card and read-only preview want the locale-specific names.
class _LocationLabelsHost extends StatefulWidget {
  const _LocationLabelsHost({required this.listings, required this.builder});

  final List<PublisherListing> listings;
  final Widget Function(
    BuildContext context,
    Map<String, Governorate> governorates,
    Map<String, Area> areas,
  )
  builder;

  @override
  State<_LocationLabelsHost> createState() => _LocationLabelsHostState();
}

class _LocationLabelsHostState extends State<_LocationLabelsHost> {
  final Map<String, Governorate> _governorates = {};
  final Map<String, Area> _areas = {};
  final Set<String> _inflightGovs = {};
  final Set<String> _inflightAreas = {};

  late final LocationsRepository _repo = getIt<LocationsRepository>();

  @override
  void initState() {
    super.initState();
    _resolveMissing();
  }

  @override
  void didUpdateWidget(_LocationLabelsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameIdSet(oldWidget.listings, widget.listings)) {
      _resolveMissing();
    }
  }

  bool _sameIdSet(List<PublisherListing> a, List<PublisherListing> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].listing.id != b[i].listing.id) return false;
      if (a[i].listing.governorateId != b[i].listing.governorateId) {
        return false;
      }
      if (a[i].listing.areaId != b[i].listing.areaId) return false;
    }
    return true;
  }

  Future<void> _resolveMissing() async {
    final neededGovs = <String>{};
    final neededAreas = <String>{};
    for (final pl in widget.listings) {
      final g = pl.listing.governorateId;
      final a = pl.listing.areaId;
      if (g != null &&
          !_governorates.containsKey(g) &&
          !_inflightGovs.contains(g)) {
        neededGovs.add(g);
      }
      if (a != null && !_areas.containsKey(a) && !_inflightAreas.contains(a)) {
        neededAreas.add(a);
      }
    }
    if (neededGovs.isEmpty && neededAreas.isEmpty) return;
    _inflightGovs.addAll(neededGovs);
    _inflightAreas.addAll(neededAreas);

    for (final id in neededGovs) {
      unawaited(_fetchGov(id));
    }
    for (final id in neededAreas) {
      unawaited(_fetchArea(id));
    }
  }

  Future<void> _fetchGov(String id) async {
    try {
      final g = await _repo.loadGovernorate(id);
      if (!mounted) return;
      setState(() {
        _governorates[id] = g;
        _inflightGovs.remove(id);
      });
    } catch (_) {
      if (!mounted) return;
      // Leave the cache empty; card falls back to no label rather than ID.
      setState(() => _inflightGovs.remove(id));
    }
  }

  Future<void> _fetchArea(String id) async {
    try {
      final a = await _repo.loadArea(id);
      if (!mounted) return;
      setState(() {
        _areas[id] = a;
        _inflightAreas.remove(id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _inflightAreas.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _governorates, _areas);
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyState(
      icon: LucideIcons.list_plus,
      headline: l10n.myListingsEmptyTitle,
      ctaLabel: l10n.myListingsEmptyCtaCreateFirst,
      onCtaPressed: () =>
          context.goNamed(AppRouteNames.publisherListingsCreate),
    );
  }
}

/// Phase 12 / US2 — wraps the Phase 10 `ListingCard` with the Phase 12
/// `RejectionReasonBanner` for `status == rejected` rows. Non-rejected
/// rows render the bare `ListingCard` (Phase 10 behaviour unchanged).
class _ListingRow extends StatelessWidget {
  const _ListingRow({
    required this.publisherListing,
    required this.currenciesByCode,
    required this.governoratesById,
    required this.areasById,
  });

  final PublisherListing publisherListing;
  final Map<String, Currency> currenciesByCode;
  final Map<String, Governorate> governoratesById;
  final Map<String, Area> areasById;

  @override
  Widget build(BuildContext context) {
    final isRejected =
        publisherListing.listing.status == ListingStatus.rejected;

    // Phase 031 (WS-B) — for an APPROVED listing, look up whether an open
    // pending_review revision exists so the card can show "Edit in review".
    if (publisherListing.isRevisionEditable) {
      return _ApprovedRevisionCardLoader(
        publisherListing: publisherListing,
        currenciesByCode: currenciesByCode,
        governoratesById: governoratesById,
        areasById: areasById,
      );
    }

    final card = ListingCard(
      publisherListing: publisherListing,
      currenciesByCode: currenciesByCode,
      governoratesById: governoratesById,
      areasById: areasById,
      // For rejected listings the Phase 12 banner above renders the parsed
      // preset + detail + Resubmit + View moderation history in a localised
      // form; suppress the legacy raw-JSON in-card block to avoid the
      // double-display + raw JSON leak.
      hideLegacyRejectionBlock: isRejected,
    );

    if (!isRejected) {
      return card;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RejectionBannerLoader(listingId: publisherListing.listing.id),
        card,
      ],
    );
  }
}

/// Phase 031 (WS-B) — resolves whether an APPROVED listing has an open
/// `pending_review` revision (so the card shows the "Edit in review" badge
/// instead of the "Edit (needs approval)" hint). Best-effort: any failure
/// degrades to the plain affordance hint.
class _ApprovedRevisionCardLoader extends StatefulWidget {
  const _ApprovedRevisionCardLoader({
    required this.publisherListing,
    required this.currenciesByCode,
    required this.governoratesById,
    required this.areasById,
  });

  final PublisherListing publisherListing;
  final Map<String, Currency> currenciesByCode;
  final Map<String, Governorate> governoratesById;
  final Map<String, Area> areasById;

  @override
  State<_ApprovedRevisionCardLoader> createState() =>
      _ApprovedRevisionCardLoaderState();
}

class _ApprovedRevisionCardLoaderState
    extends State<_ApprovedRevisionCardLoader> {
  late Future<ListingRevision?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(_ApprovedRevisionCardLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publisherListing.listing.id !=
        widget.publisherListing.listing.id) {
      _future = _load();
    }
  }

  Future<ListingRevision?> _load() async {
    try {
      return await getIt<FindOpenRevision>().call(
        widget.publisherListing.listing.id,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ListingRevision?>(
      future: _future,
      builder: (context, snapshot) {
        final editInReview = snapshot.data?.isPending ?? false;
        return ListingCard(
          publisherListing: widget.publisherListing,
          currenciesByCode: widget.currenciesByCode,
          governoratesById: widget.governoratesById,
          areasById: widget.areasById,
          editInReview: editInReview,
        );
      },
    );
  }
}

class _RejectionBannerLoader extends StatefulWidget {
  const _RejectionBannerLoader({required this.listingId});

  final String listingId;

  @override
  State<_RejectionBannerLoader> createState() => _RejectionBannerLoaderState();
}

class _RejectionBannerLoaderState extends State<_RejectionBannerLoader> {
  late Future<Result<ModerationHistoryEntry?>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<LoadMostRecentRejectionUseCase>().call(widget.listingId);
  }

  @override
  void didUpdateWidget(_RejectionBannerLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listingId != widget.listingId) {
      _future = getIt<LoadMostRecentRejectionUseCase>().call(widget.listingId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<ModerationHistoryEntry?>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BannerSkeleton();
        }
        final result = snapshot.data;
        if (result is Success<ModerationHistoryEntry?>) {
          final entry = result.value;
          if (entry == null || entry.rejectionPreset == null) {
            return const SizedBox.shrink();
          }
          return RejectionReasonBanner(
            listingId: widget.listingId,
            preset: entry.rejectionPreset!,
            detail: entry.rejectionDetail,
            rejectedAt: entry.changedAt,
          );
        }
        // Failures intentionally suppressed — the rejected card itself
        // still renders Phase 10's RejectionReasonBlock + ResubmitCta as a
        // graceful degradation.
        return const SizedBox.shrink();
      },
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: AppSpacing.xxxl + AppSpacing.xl,
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.error.withValues(alpha: 0.20)),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ErrorState(
      title: l10n.myListingsErrorPrefix,
      message: message,
      onRetry: () =>
          context.read<MyListingsBloc>().add(const LoadMyListings()),
    );
  }
}
