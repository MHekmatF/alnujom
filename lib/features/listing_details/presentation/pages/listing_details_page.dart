import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/hero_tags.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../features/listing_form/domain/entities/listing.dart'
    show Listing, LocationVisibility, PropertyTypeDb;
import '../../../../features/map/domain/entities/map_entry_context.dart';
import '../../../../features/map/domain/entities/marker_coordinates.dart';
import '../../../../features/currencies/domain/entities/currency.dart';
import '../../../../features/listing_form/domain/entities/listing_media.dart';
import '../../../../features/listing_form/domain/entities/listing_price.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/widgets/listing_display/listing_amenities_block.dart';
import '../../../../shared/presentation/widgets/listing_display/listing_description_block.dart';
import '../../../../shared/presentation/widgets/listing_display/listing_gallery.dart';
import '../../../../shared/presentation/widgets/listing_display/listing_location_block.dart';
import '../../../../shared/presentation/widgets/listing_display/listing_price_block.dart';
import '../../domain/entities/listing_details_aggregate.dart';
import '../bloc/listing_details_bloc.dart';
import '../widgets/affordability_calculator.dart';
import '../widgets/buyer_safety_banner.dart';
import '../widgets/contact_block.dart';
import '../widgets/listing_details_skeleton.dart';
import '../widgets/listing_facts_block.dart';
import '../widgets/per_listing_action_block.dart';
import '../widgets/similar_listings_carousel.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../ads/domain/entities/ad_placement.dart';
import '../../../ads/presentation/widgets/ad_slot.dart';
import '../../../reports/presentation/widgets/reporter_status_banner.dart';
import '../../../agency/presentation/widgets/listing_agency_badge.dart';
import '../../../reviews/presentation/bloc/seller_trust_cubit.dart';
import '../../../reviews/presentation/widgets/seller_reviews_section.dart';
import '../../../recently_viewed/domain/entities/recently_viewed_listing.dart';
import '../../../recently_viewed/presentation/bloc/recently_viewed_cubit.dart';
import '../../data/listing_details_video_launcher.dart';
import 'panorama_tour_page.dart';
import '../../../../core/widgets/glass_pill.dart';

/// Phase 13 (spec/013-home-and-details) — listing details page.
///
/// Composition (top-to-bottom per contracts/phase13-listing-details-page-composition.md):
/// 1. AppBar with Q4=D conditional back arrow per R-71 + contracts/phase13-deep-link-back-button.md
/// 2. ListingGallery (Phase 12 Q8=A — imported VERBATIM, zero edits per SC-016)
///    FR-027 GAP: Phase 12's ListingGallery has NO onVideoTap callback in its
///    public API. Video tap is implemented via [_GalleryWithVideoTap] which
///    wraps the gallery with a GestureDetector overlay + delegates to
///    [ListingDetailsVideoLauncher] (data-layer helper) for FR-030 compliance.
/// 3. Listing title (headlineSmall typography token)
/// 4. ListingPriceBlock (Phase 12 Q8=A — VERBATIM)
/// 5. ListingLocationBlock (Phase 12 Q8=A — VERBATIM)
/// 6. ContactBlock (Phase 13 Q2=A stubs — three Coming-soon snackbars)
/// 7. ListingAmenitiesBlock (Phase 12 Q8=A — VERBATIM)
/// 8. ListingDescriptionBlock (Phase 12 Q8=A — VERBATIM)
/// 9. PerListingActionBlock (Phase 13 Q2=A stubs — three Coming-soon snackbars)
///
/// FR-011 (LOCKED): page-level not-found via BLoC failure — NOT router
/// errorBuilder. Unifies malformed-UUID + RLS-hidden + non-existent under the
/// same UX per Constitution III no-leak rule.
class ListingDetailsPage extends StatelessWidget {
  const ListingDetailsPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<ListingDetailsBloc>()..add(ListingDetailsLoadRequested(id)),
      child: _ListingDetailsView(id: id),
    );
  }
}

// ─── Main view ────────────────────────────────────────────────────────────────

class _ListingDetailsView extends StatelessWidget {
  const _ListingDetailsView({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // System back gesture path — DeepLinkAwareBackButton handles the
        // AppBar tap path. Inline the same Q4=D conditional logic here so the
        // two paths remain semantically equivalent.
        if (!didPop) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.go(AppRoutes.home);
          }
        }
      },
      child: BlocBuilder<ListingDetailsBloc, ListingDetailsState>(
        builder: (context, state) {
          switch (state.status) {
            case ListingDetailsStatus.initial:
            case ListingDetailsStatus.loading:
              return _chromeScaffold(const ListingDetailsSkeleton());
            case ListingDetailsStatus.notFound:
              return _chromeScaffold(const _NotFoundView());
            case ListingDetailsStatus.error:
              return _chromeScaffold(
                _ErrorView(
                  onRetry: () => context.read<ListingDetailsBloc>().add(
                    const ListingDetailsRetryRequested(),
                  ),
                ),
              );
            case ListingDetailsStatus.success:
              final aggregate = state.aggregate;
              if (aggregate == null) {
                return _chromeScaffold(const ListingDetailsSkeleton());
              }
              // Success owns its own Scaffold whose SliverAppBar IS the bar
              // (a parallax collapsing gallery), so no top-level AppBar here.
              return _SuccessBody(aggregate: aggregate);
          }
        },
      ),
    );
  }

  /// Plain-chrome scaffold (back-button AppBar) for the non-success states.
  Widget _chromeScaffold(Widget body) => Scaffold(
    appBar: AppBar(leading: const DeepLinkAwareBackButton()),
    body: body,
  );
}

// ─── Success body ─────────────────────────────────────────────────────────────

class _SuccessBody extends StatefulWidget {
  const _SuccessBody({required this.aggregate});

  final ListingDetailsAggregate aggregate;

  @override
  State<_SuccessBody> createState() => _SuccessBodyState();
}

class _SuccessBodyState extends State<_SuccessBody> {
  @override
  void initState() {
    super.initState();
    // Recently-viewed: record this listing once when the success body mounts.
    // Best-effort + local-only; fired post-frame so it never competes with the
    // first paint, and uses the active locale for the governorate snapshot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recordRecentlyViewed(Localizations.localeOf(context));
    });

    // Product analytics — a listing loaded (the success body mounts only once
    // the aggregate is available). Best-effort; no-op when telemetry is off.
    getIt<AnalyticsService>().logEvent(
      'listing_viewed',
      props: {'id': widget.aggregate.listing.id},
    );
  }

  /// Captures a small snapshot of the loaded aggregate into the shared
  /// [RecentlyViewedCubit] (de-duped by id, capped, most-recent-first). The main
  /// image storage path is resolved to a public URL by the data layer so this
  /// presentation file never touches Supabase.
  void _recordRecentlyViewed(Locale locale) {
    final aggregate = widget.aggregate;
    final cubit = getIt<RecentlyViewedCubit>();

    final mainMedia = _mainImageMedia(aggregate.media);
    final primaryPrice = aggregate.prices.isEmpty
        ? null
        : aggregate.prices.firstWhere(
            (p) => p.isPrimary,
            orElse: () => aggregate.prices.first,
          );
    final governorateName = aggregate.governorate.localizedName(locale);

    cubit.record(
      RecentlyViewedListing(
        id: aggregate.listing.id,
        title: aggregate.listing.title,
        mainImageUrl: cubit.resolveImageUrl(mainMedia?.storagePath),
        priceAmount: primaryPrice?.amount.toString(),
        currencyCode: primaryPrice?.currencyCode,
        governorateName:
            governorateName.isEmpty ? null : governorateName,
      ),
    );
  }

  /// The listing's main image media (is_main first, then ordering ASC),
  /// restricted to image rows with a storage path; null when none qualifies.
  ListingMedia? _mainImageMedia(List<ListingMedia> media) {
    final images = media
        .where((m) =>
            m.kind == ListingMediaKind.image && m.storagePath != null)
        .toList()
      ..sort((a, b) {
        if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
        return a.ordering.compareTo(b.ordering);
      });
    return images.isEmpty ? null : images.first;
  }

  @override
  Widget build(BuildContext context) {
    final aggregate = widget.aggregate;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Build a minimal Currency shim from the primary price for ListingPriceBlock.
    // Phase 16 replaces this with the user's display-currency preference from
    // Phase 9's exchange-rates / user_preferences tables.
    final Currency? displayCurrency = aggregate.prices.isNotEmpty
        ? _buildDisplayCurrency(aggregate)
        : null;

    final galleryHeight = MediaQuery.sizeOf(context).width * 9 / 16;
    // Seller-trust layer: one cubit for the whole success body, seeded with the
    // seller's user id. The contact card's rating/response summary and the
    // Reviews section both read it, so loading happens once here.
    return BlocProvider<SellerTrustCubit>(
      create: (_) =>
          getIt<SellerTrustCubit>()..load(aggregate.listing.publisherUserId),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
          // 2. Parallax collapsing gallery + FR-027 video-tap overlay.
          //    Phase 12 Q8=A ListingGallery wrapped (not edited) per SC-016;
          //    it also owns the Hero destination flown from the home card.
          SliverAppBar(
            pinned: true,
            expandedHeight: galleryHeight,
            leading: const DeepLinkAwareBackButton(),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _GalleryWithVideoTap(
                media: aggregate.media,
                heroTag: listingImageHeroTag(aggregate.listing.id),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StaggeredListItem(
              index: 1,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phase 18: Reporter status banner (renders nothing for non-
                    // reporters / anon). Self-contained: hosts its own cubit.
                    ReporterStatusBanner(listingId: aggregate.listing.id),
                    // Phase 21: listing details banner (collapses to zero height
                    // when no eligible ads — FR-012; no reflow on the details layout).
                    const AdSlot(placement: AdPlacement.listingDetailsBanner),
                    // 3. Listing title — headlineMedium is a theme-set Cairo slot
                    // (headlineSmall is unset and would fall back to the default
                    // non-Arabic font).
                    Text(
                      aggregate.listing.title,
                      style: theme.textTheme.headlineMedium,
                    ),
                    if (aggregate.publisher.fullName.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.listing_details_publisher_label(
                          aggregate.publisher.fullName,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    // Phase 19 (FR-022/T061): verified-agency badge. Renders
                    // nothing unless the listing's agency is approved. Does NOT
                    // alter the Phase 13/17/18 Favorite/Share/Report CTAs.
                    if (aggregate.listing.agencyId != null)
                      ListingAgencyBadge(agencyId: aggregate.listing.agencyId!),
                    const SizedBox(height: AppSpacing.md),
                    // 4. Price block — Phase 12 Q8=A VERBATIM
                    if (displayCurrency != null &&
                        aggregate.prices.isNotEmpty) ...[
                      ListingPriceBlock(
                        prices: aggregate.prices,
                        displayCurrency: displayCurrency,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    // 4b. Premium uplift v2 — key facts grid (beds·baths·area·
                    //     floor·type) right under the title/price. Collapses to
                    //     nothing when the listing has none of these.
                    ListingFactsBlock(listing: aggregate.listing),
                    const SizedBox(height: AppSpacing.md),
                    // 4c. Premium uplift — financing ("حاسبة التمويل")
                    //     calculator, expandable, seeded with the primary price.
                    //     Indicative only; no currency conversion, no network.
                    if (displayCurrency != null &&
                        aggregate.prices.isNotEmpty) ...[
                      AffordabilityCalculator(
                        price: _primaryPrice(aggregate).amount,
                        currencyCode: _primaryPrice(aggregate).currencyCode,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    // 5. Location block — Phase 12 Q8=A VERBATIM (widget itself unmodified)
                    ListingLocationBlock(
                      governorate: aggregate.governorate,
                      city: aggregate.city,
                      area: aggregate.area,
                      addressText: aggregate.listing.addressText,
                    ),
                    // 5b. Phase 15 G2: "View on map" affordance — consumer wrap.
                    //     Only rendered when location_visibility permits map presence.
                    //     ListingLocationBlock itself is NOT modified (Phase 12 Q8=A purity).
                    if (_canShowOnMap(aggregate.listing))
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.lg,
                          AppSpacing.xs,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: () => context.go(
                              AppRoutes.map,
                              extra: MapEntryFromListing(
                                listingId: aggregate.listing.id,
                                position: MarkerCoordinates(
                                  latitude: aggregate.listing.latitude!,
                                  longitude: aggregate.listing.longitude!,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.map_outlined),
                            label: Text(
                              l10n.listing_details_view_on_map_action,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    // 5c. Premium uplift — buyer-safety reassurance banner,
                    //     placed just above the contact section so the buyer
                    //     reads it before reaching out. Informational only.
                    const BuyerSafetyBanner(),
                    const SizedBox(height: AppSpacing.md),
                    // 6. Contact block — Phase 16 rewired (listing passed for
                    //    ContactCtaCubit). Premium uplift v2: richer AgentCard
                    //    surface seeded with the publisher's name + username.
                    ContactBlock(
                      listing: aggregate.listing,
                      contactName: aggregate.publisher.fullName.isNotEmpty
                          ? aggregate.publisher.fullName
                          : null,
                      subtitle: aggregate.publisher.username != null &&
                              aggregate.publisher.username!.isNotEmpty
                          ? l10n.listing_details_contact_username(
                              aggregate.publisher.username!,
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // 6b. Seller-trust "Reviews" section — header (avg + count),
                    //     recent reviews, and a context-aware write affordance.
                    //     Reads the page-level SellerTrustCubit; collapses when
                    //     there's nothing to show and the viewer can't write.
                    SellerReviewsSection(
                      sellerId: aggregate.listing.publisherUserId,
                      listingId: aggregate.listing.id,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // 7. Amenities block — Phase 12 Q8=A VERBATIM
                    ListingAmenitiesBlock(
                      amenities: aggregate.details.amenities,
                    ),
                    if (aggregate.details.amenities.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    // 8. Description block — Phase 12 Q8=A VERBATIM
                    if (aggregate.details.description != null &&
                        aggregate.details.description!.trim().isNotEmpty) ...[
                      ListingDescriptionBlock(
                        description: aggregate.details.description!,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    // 9. Per-listing action block — Favorite + Report live;
                    //    Share now live (premium uplift v2) with title + price.
                    PerListingActionBlock(
                      listingId: aggregate.listing.id,
                      shareTitle: aggregate.listing.title,
                      sharePrice: _sharePriceText(
                        context,
                        aggregate,
                        displayCurrency,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
          // 10. Premium uplift v2 — "similar listings" carousel: same property
          //     type + governorate, excluding this listing. Self-contained
          //     (hosts its own cubit); collapses when the pool is empty.
          SliverToBoxAdapter(
            child: SimilarListingsCarousel(
              listingId: aggregate.listing.id,
              propertyType: aggregate.listing.propertyType.toDbValue(),
              propertyTypeEnum: aggregate.listing.propertyType,
              governorateId: aggregate.listing.governorateId,
              staggerIndex: 2,
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.lg),
          ),
          ],
        ),
      ),
    );
  }

  /// Builds the localized primary-price string for the share payload, or null
  /// when no price / currency is available.
  String? _sharePriceText(
    BuildContext context,
    ListingDetailsAggregate aggregate,
    Currency? displayCurrency,
  ) {
    if (displayCurrency == null || aggregate.prices.isEmpty) return null;
    final primary = aggregate.prices.firstWhere(
      (p) => p.isPrimary,
      orElse: () => aggregate.prices.first,
    );
    return MoneyFormatter.format(
      Money(amount: primary.amount, currencyCode: primary.currencyCode),
      locale: Localizations.localeOf(context),
      currency: displayCurrency,
    );
  }

  /// The listing's primary price (isPrimary first, else the first available).
  /// Caller must guard on `aggregate.prices.isNotEmpty`.
  ListingPrice _primaryPrice(ListingDetailsAggregate aggregate) {
    return aggregate.prices.firstWhere(
      (p) => p.isPrimary,
      orElse: () => aggregate.prices.first,
    );
  }

  Currency _buildDisplayCurrency(ListingDetailsAggregate aggregate) {
    final primary = aggregate.prices.firstWhere(
      (p) => p.isPrimary,
      orElse: () => aggregate.prices.first,
    );
    return Currency(
      code: primary.currencyCode,
      nameAr: primary.currencyCode,
      nameEn: primary.currencyCode,
      symbol: primary.currencyCode,
      isActive: true,
      sortOrder: 0,
      isSystem: false,
      displayDecimals: 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

// ─── Phase 15 G2 helper ───────────────────────────────────────────────────────

/// Returns true when the listing's [LocationVisibility] permits map presence
/// (i.e. exact or approximate). Hidden and admin_only listings are excluded.
///
/// Phase 10 Q2=A guarantees that latitude + longitude are non-null whenever
/// visibility is exact or approximate (auto-populated from area centroid on
/// submit), so the null-bang assertions in the caller are safe.
bool _canShowOnMap(Listing listing) {
  return listing.locationVisibility == LocationVisibility.exact ||
      listing.locationVisibility == LocationVisibility.approximate;
}

// ─── Gallery with video-tap overlay ──────────────────────────────────────────

/// Wraps [ListingGallery] (Phase 12 Q8=A — zero edits per SC-016) with a
/// [GestureDetector] overlay for FR-027 video tap → url_launcher.
///
/// DOCUMENTED GAP: Phase 12's [ListingGallery] has no `onVideoTap` callback.
/// The Supabase URL resolution is delegated to [ListingDetailsVideoLauncher]
/// in the data layer (lib/features/listing_details/data/) to maintain FR-030
/// isolation — the page itself imports zero `package:supabase_flutter`.
class _GalleryWithVideoTap extends StatefulWidget {
  const _GalleryWithVideoTap({required this.media, this.heroTag});

  final List<ListingMedia> media;

  /// When set, the gallery owns the Hero flight from the listing card's image.
  final Object? heroTag;

  @override
  State<_GalleryWithVideoTap> createState() => _GalleryWithVideoTapState();
}

class _GalleryWithVideoTapState extends State<_GalleryWithVideoTap> {
  int _currentPage = 0;

  // Replicate the sort order from ListingGallery's internal sort logic:
  // is_main first, then ordering ASC.
  List<ListingMedia> get _sortedMedia {
    final sorted = [...widget.media];
    sorted.sort((a, b) {
      if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
      return a.ordering.compareTo(b.ordering);
    });
    return sorted;
  }

  ListingMedia? get _currentVideoMedia {
    final sorted = _sortedMedia;
    if (sorted.isEmpty) return null;
    final item = sorted[_currentPage.clamp(0, sorted.length - 1)];
    if (item.kind == ListingMediaKind.video && item.storagePath != null) {
      return item;
    }
    return null;
  }

  /// The first 360°/virtual-tour panorama row in the listing's media, or null
  /// when the listing has none. Detected from the preserved free-text
  /// [ListingMedia.rawKind] (`kind='panorama'`) — the closed [ListingMediaKind]
  /// enum collapses panoramas to `image`, so the entity exposes [ListingMedia
  /// .isPanorama] for this purpose. Used both to gate the 360° affordance and to
  /// pick which equirectangular image to open in the [PanoramaTourPage].
  ListingMedia? get _firstPanorama {
    for (final m in _sortedMedia) {
      if (m.isPanorama) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final videoMedia = _currentVideoMedia;
    final panorama = _firstPanorama;
    final sorted = _sortedMedia;

    // Phase 12 Q8=A ListingGallery wrapped (not edited) per SC-016. A slow
    // Ken Burns zoom/pan is layered on via the wrapper (clipped by the header),
    // then the Hero flight from the listing card image.
    Widget gallery = ListingGallery(media: widget.media);
    if (!reduceMotion(context)) {
      gallery = ClipRect(child: _KenBurns(child: gallery));
    }
    if (widget.heroTag != null) {
      gallery = Hero(tag: widget.heroTag!, child: gallery);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          if (sorted.length > 1) {
            final pageWidth = notification.metrics.viewportDimension;
            if (pageWidth > 0) {
              final page = (notification.metrics.pixels / pageWidth)
                  .round()
                  .clamp(0, sorted.length - 1);
              if (page != _currentPage) {
                setState(() => _currentPage = page);
              }
            }
          }
        }
        return false;
      },
      child: Stack(
        alignment: AlignmentDirectional.bottomCenter,
        children: [
          GestureDetector(
            // FR-027: only intercept taps when the visible item is a video.
            onTap: videoMedia != null
                ? () => ListingDetailsVideoLauncher.launch(videoMedia)
                : null,
            child: gallery,
          ),
          // Spec 026 — 360°/virtual-tour affordance. When the listing has any
          // panorama row, a frosted "360°" pill sits at the top-END (the
          // top-start is reserved for the back button): it both BADGES the
          // presence of a virtual tour and, on tap, opens the first panorama
          // full-screen in [PanoramaTourPage]. Mirrors the video-tap wrapper
          // approach (overlay on the locked ListingGallery), so the Phase 12
          // Q8=A gallery itself is never edited.
          if (panorama != null)
            PositionedDirectional(
              top: AppSpacing.md,
              end: AppSpacing.md,
              child: _PanoramaPillButton(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PanoramaTourPage.fromMedia(panorama),
                  ),
                ),
              ),
            ),
          if (sorted.length > 1)
            PositionedDirectional(
              bottom: AppSpacing.md,
              child: _GalleryDots(
                count: sorted.length,
                current: _currentPage.clamp(0, sorted.length - 1),
              ),
            ),
        ],
      ),
    );
  }
}

/// Spec 026 — the gallery's "360°" affordance: a frosted [GlassPill] that
/// both signals a virtual tour exists AND opens it on tap. Wrapped in a
/// transparent [InkWell] so the visual stays the shared [GlassPill] (token-
/// clean) while gaining tap + ripple + a button semantic.
class _PanoramaPillButton extends StatelessWidget {
  const _PanoramaPillButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.panoramaTourOpen,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: appRadius(AppRadii.pill),
        child: GlassPill(
          label: l10n.panoramaTourBadge,
          icon: Icons.threesixty,
        ),
      ),
    );
  }
}

/// Animated page indicator over the gallery: the active dot widens. White on
/// imagery, so theme-independent by design.
class _GalleryDots extends StatelessWidget {
  const _GalleryDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == current;
        final onPhoto = AppColors.of(context).onPhoto;
        return AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.curve,
          margin: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xs,
          ),
          width: active ? AppSpacing.lg : AppSpacing.sm,
          height: AppSpacing.sm,
          decoration: BoxDecoration(
            color: active ? onPhoto : onPhoto.withValues(alpha: 0.5),
            borderRadius: appRadius(AppRadii.pill),
          ),
        );
      }),
    );
  }
}

/// A slow, breathing Ken Burns effect (zoom + gentle horizontal pan) applied to
/// the gallery image. Reverses every ~18s so it never jumps. Clipped by the
/// caller so the zoom stays within the header frame.
class _KenBurns extends StatefulWidget {
  const _KenBurns({required this.child});

  final Widget child;

  @override
  State<_KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<_KenBurns>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 1.0 + 0.12 * t,
          alignment: Alignment(-0.18 + 0.36 * t, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─── Not-found view ───────────────────────────────────────────────────────────

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyState(
      icon: Icons.search_off_rounded,
      headline: l10n.listing_details_not_found_title,
      ctaLabel: l10n.listing_details_not_found_return_home,
      onCtaPressed: () => context.go(AppRoutes.home),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ErrorState(
      title: l10n.error_could_not_load_listing,
      variant: ErrorStateVariant.network,
      onRetry: onRetry,
    );
  }
}
