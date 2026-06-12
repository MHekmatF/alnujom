// lib/features/ads/presentation/widgets/ad_slot.dart
//
// Phase 21 (spec/021-ads-banners) — AdSlot (T034).
//
// The public entry widget for all ad placements.
//
// Behaviour:
//   - Creates an [AdSlotCubit] (factory via GetIt) + calls load() on init.
//   - 0 eligible ads (empty / error / initial) → [SizedBox.shrink()] (FR-012,
//     no reflow in the host layout).
//   - 1 ad → static [AdBannerCard] (no timer).
//   - ≥2 ads → [AdCarousel] with auto-advance + page indicator.
//
// Tap-through (FR-017 / FR-018):
//   1. [RecordAdClick] is called best-effort (fire-and-forget); errors
//      are swallowed — the navigation proceeds regardless.
//   2. Target is opened by [AdLinkKind]:
//        external  → launchUrl(Uri.parse(linkValue), externalApplication)
//        listing   → context.push(AppRoutes.listingDetailsFor(linkValue))
//        agency    → context.push('/agency/$linkValue')
//        search    → context.push(AppRoutes.search, extra: query string)
//        category  → context.push(AppRoutes.search, extra: PropertyType)
//   3. Unresolved / bad target → snackbar + no crash (FR-018).

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart'
    show PropertyType, PropertyTypeDb;
import '../../domain/entities/ad_link.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/entities/serving_ad.dart';
import '../../domain/usecases/record_ad_click.dart';
import '../bloc/ad_slot_cubit.dart';
import 'ad_banner_card.dart';
import 'ad_carousel.dart';

class AdSlot extends StatelessWidget {
  const AdSlot({super.key, required this.placement});

  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdSlotCubit>(
      create: (_) => getIt<AdSlotCubit>()..load(placement),
      child: _AdSlotView(placement: placement),
    );
  }
}

class _AdSlotView extends StatelessWidget {
  const _AdSlotView({required this.placement});

  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdSlotCubit, AdSlotState>(
      builder: (context, state) {
        return switch (state) {
          AdSlotSingle(:final ad) => AdBannerCard(
            ad: ad,
            onTap: () => _handleTap(context, ad),
          ),
          AdSlotCarousel(:final ads) => AdCarousel(
            ads: ads,
            onAdTap: (ad) => _handleTap(context, ad),
          ),
          // initial / empty / error → zero height, no reflow (FR-012)
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  /// Fires RecordAdClick best-effort (non-blocking), then opens the target.
  /// Swallows all click-recording errors per FR-017.
  void _handleTap(BuildContext context, ServingAd ad) {
    // Best-effort, non-blocking — do NOT await.
    getIt<RecordAdClick>().call(adId: ad.adId, placement: placement).ignore();

    _openTarget(context, ad);
  }

  Future<void> _openTarget(BuildContext context, ServingAd ad) async {
    try {
      switch (ad.linkKind) {
        case AdLinkKind.external:
          final uri = Uri.tryParse(ad.linkValue);
          if (uri == null || !uri.hasScheme) {
            _showFallback(context);
            return;
          }
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched && context.mounted) {
            _showFallback(context);
          }

        case AdLinkKind.listing:
          if (context.mounted) {
            unawaited(context.push(AppRoutes.listingDetailsFor(ad.linkValue)));
          }

        case AdLinkKind.agency:
          if (context.mounted) {
            unawaited(context.push('/agency/${ad.linkValue}'));
          }

        case AdLinkKind.search:
          if (context.mounted) {
            // SearchPage accepts PropertyType? as extra (R-179). For a text-
            // search link kind we navigate with no extra; the search bar
            // autofocuses (text pre-fill is a PA/future-phase concern).
            unawaited(context.push(AppRoutes.search));
          }

        case AdLinkKind.category:
          PropertyType? propertyType;
          try {
            propertyType = PropertyTypeDb.fromDbValue(ad.linkValue);
          } catch (_) {
            propertyType = null;
          }
          if (context.mounted) {
            unawaited(context.push(AppRoutes.search, extra: propertyType));
          }
      }
    } catch (_) {
      // Graceful fallback on any unresolved target (FR-018).
      if (context.mounted) {
        _showFallback(context);
      }
    }
  }

  void _showFallback(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = l10n?.adSlotTargetNotFound ?? 'Link unavailable';
    AppToast.warning(context, message);
  }
}
