// lib/features/ads/presentation/widgets/ad_carousel.dart
//
// Phase 21 (spec/021-ads-banners) — AdCarousel (T033).
//
// Renders ≥2 [ServingAd]s as a looping [PageView] with:
//   - Auto-advance [Timer] (~5 s) — pure client-side UI, no network/Realtime
//   - Manual swipe
//   - Page-dot indicator (Phase 2 tokens, no inline hex)
//
// A single ad from the caller renders [AdBannerCard] directly (no timer here).
// The [Timer] is cancelled in [dispose] to prevent memory leaks.
// Ads are already ordered `priority DESC` by the datasource (R-173).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../domain/entities/serving_ad.dart';
import 'ad_banner_card.dart';

class AdCarousel extends StatefulWidget {
  const AdCarousel({super.key, required this.ads, required this.onAdTap});

  /// ≥2 ads ordered priority DESC (R-173). Must not be empty.
  final List<ServingAd> ads;

  /// Called when the user taps a banner; receives the tapped [ServingAd].
  final void Function(ServingAd ad) onAdTap;

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  static const Duration _autoAdvanceDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(_autoAdvanceDuration, (_) {
      if (!mounted) return;
      final nextPage = (_currentPage + 1) % widget.ads.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: widget.ads.length,
          itemBuilder: (context, index) {
            final ad = widget.ads[index];
            return Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xs,
              ),
              child: AdBannerCard(ad: ad, onTap: () => widget.onAdTap(ad)),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        _PageIndicator(count: widget.ads.length, current: _currentPage),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xs,
          ),
          width: isActive ? AppSpacing.md : AppSpacing.sm,
          height: AppSpacing.xs,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppSpacing.xs),
          ),
        );
      }),
    );
  }
}
