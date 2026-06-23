import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/settings/lite_mode.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/glass_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/reel.dart';
import '../bloc/reels_feed_cubit.dart';
import '../widgets/reel_player.dart';

/// Phase 029 (Reels W4) — the fullscreen vertical in-app video feed.
///
/// A vertical [PageView] of reels. At any moment at most THREE
/// [VideoPlayerController]s are alive — {current-1, current, current+1} (or just
/// {current-1, current} in Data-saver mode) — and only the current one ever
/// plays. Controllers outside that window are disposed eagerly so memory stays
/// flat on low-end devices.
///
/// Reached by `Navigator.push(MaterialPageRoute(...))` from the home rail (and
/// optionally seeded with the rail's already-loaded first page).
class ReelsFeedPage extends StatelessWidget {
  const ReelsFeedPage({super.key, this.initialReels});

  /// Optional pre-loaded first page (from the rail) so the feed paints
  /// instantly. When null the page fetches its own first page.
  final List<Reel>? initialReels;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return BlocProvider<ReelsFeedCubit>(
      create: (_) {
        final cubit = getIt<ReelsFeedCubit>();
        final seed = initialReels;
        if (seed != null && seed.isNotEmpty) {
          cubit.seed(seed);
        } else {
          cubit.loadInitial(locale: locale);
        }
        return cubit;
      },
      child: const ReelsFeedBody(),
    );
  }
}

/// Phase 030 (W4) — the reusable feed BODY shared by the pushed fullscreen
/// [ReelsFeedPage] (home rail) and the persistent [ReelsTabPage] (bottom-nav
/// Reels tab). Expects an ancestor [BlocProvider]<[ReelsFeedCubit]> to already
/// be seeded/loading; it owns the [PageView], the ≤3-controller window and the
/// mute/Data-saver chrome. Disposes every [VideoPlayerController] when removed
/// from the tree (and pauses the current one on `deactivate`, so leaving the
/// tab via the bottom nav stops playback immediately).
///
/// [emptyBody] is an optional friendly subtitle for the empty state — the
/// persistent tab passes one (it's always reachable now, unlike the
/// self-hiding rail), the pushed fullscreen feed leaves it null.
class ReelsFeedBody extends StatefulWidget {
  const ReelsFeedBody({super.key, this.emptyBody});

  /// Optional empty-state subtitle (the Reels tab supplies a friendly hint).
  final String? emptyBody;

  @override
  State<ReelsFeedBody> createState() => _ReelsFeedBodyState();
}

class _ReelsFeedBodyState extends State<ReelsFeedBody> {
  final PageController _pageController = PageController();

  /// The live controllers, keyed by reel index. Only ever holds the window
  /// {current-1, current, current+1} (current+1 skipped in Data-saver mode).
  final Map<int, VideoPlayerController> _controllers = {};

  int _current = 0;
  bool _muted = true;
  bool _muteHintVisible = false;
  bool _liteConfirmed = false;

  /// Set once we've kicked off the very first window build, so we don't re-run
  /// it on every rebuild.
  bool _initialWindowBuilt = false;

  @override
  void deactivate() {
    // Fires when the body is detached from the tree — e.g. the user switches
    // away from the Reels bottom-nav tab (`context.go` to another root) or the
    // pushed feed is popped. Pause playback immediately so audio/video never
    // bleeds past the route; full controller disposal happens in [dispose].
    _controllers[_current]?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  List<Reel> get _reels => context.read<ReelsFeedCubit>().state.reels;

  /// Whether to pre-init the +1 neighbour. Skipped in Data-saver mode to halve
  /// the in-flight network/decode cost on a slow connection.
  bool get _preloadNext => !LiteMode.isOn;

  /// Builds/refreshes the controller window around [_current] and disposes any
  /// controller that fell outside it. Idempotent.
  Future<void> _syncWindow() async {
    final reels = _reels;
    if (reels.isEmpty) return;

    final wanted = <int>{
      if (_current - 1 >= 0) _current - 1,
      _current,
      if (_preloadNext && _current + 1 < reels.length) _current + 1,
    };

    // Dispose controllers outside the window.
    final stale = _controllers.keys.where((i) => !wanted.contains(i)).toList();
    for (final i in stale) {
      final c = _controllers.remove(i);
      await c?.pause();
      await c?.dispose();
    }

    // Create + init the missing ones.
    for (final i in wanted) {
      if (i >= reels.length) continue;
      if (_controllers.containsKey(i)) continue;
      final reel = reels[i];
      if (reel.videoUrl.isEmpty) continue;
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(reel.videoUrl),
      );
      _controllers[i] = controller;
      try {
        await controller.initialize();
        if (!mounted || _controllers[i] != controller) {
          await controller.dispose();
          continue;
        }
        await controller.setLooping(true);
        await controller.setVolume(_muted ? 0 : 1);
        if (i == _current) {
          await controller.play();
        }
        if (mounted) setState(() {});
      } catch (_) {
        // Init failed (bad URL / codec): drop it; the poster stays visible.
        _controllers.remove(i);
        await controller.dispose();
      }
    }
  }

  Future<void> _onPageChanged(int index) async {
    if (index == _current) return;
    // Pause the one we're leaving immediately.
    await _controllers[_current]?.pause();
    if (!mounted) return;
    setState(() => _current = index);
    await _syncWindow();
    if (!mounted) return;
    // Ensure the now-current one is playing.
    final c = _controllers[index];
    if (c != null && c.value.isInitialized) {
      await c.setVolume(_muted ? 0 : 1);
      await c.play();
    }
    if (!mounted) return;
    _maybeLoadMore(index);
  }

  void _maybeLoadMore(int index) {
    if (!mounted) return;
    final reels = _reels;
    if (reels.isEmpty) return;
    // Within ~3 of the end → fetch the next keyset page.
    if (index >= reels.length - 3) {
      context.read<ReelsFeedCubit>().loadMore(
        locale: Localizations.localeOf(context),
      );
    }
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _muteHintVisible = true;
    });
    _controllers[_current]?.setVolume(_muted ? 0 : 1);
    // Hide the hint glyph shortly after.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _muteHintVisible = false);
    });
  }

  /// One-time Data-saver confirm before any video plays. Returns true to
  /// proceed. When Data saver is off, proceeds immediately.
  Future<bool> _confirmLiteIfNeeded() async {
    if (!LiteMode.isOn || _liteConfirmed) return true;
    final l10n = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: LucideIcons.triangle_alert,
        title: l10n.reels_lite_confirm_title,
        message: l10n.reels_lite_confirm_message,
        actionLabel: l10n.reels_lite_confirm_action,
        onAction: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    _liteConfirmed = proceed ?? false;
    return _liteConfirmed;
  }

  Future<void> _ensureInitialWindow() async {
    if (_initialWindowBuilt) return;
    _initialWindowBuilt = true;
    final ok = await _confirmLiteIfNeeded();
    if (!ok || !mounted) {
      // User declined data usage — leave the feed (poster-only would be odd).
      if (mounted) unawaited(Navigator.of(context).maybePop());
      return;
    }
    await _syncWindow();
    _maybeLoadMore(_current);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.scrim,
      body: BlocConsumer<ReelsFeedCubit, ReelsFeedState>(
        listenWhen: (prev, next) =>
            prev.reels.isEmpty && next.reels.isNotEmpty,
        listener: (context, state) {
          // First reels arrived (seed or first fetch) → build the window once.
          _ensureInitialWindow();
        },
        builder: (context, state) {
          switch (state.status) {
            case ReelsFeedStatus.initial:
            case ReelsFeedStatus.loading:
              return const Center(child: AppSpinner.page());
            case ReelsFeedStatus.failure:
              return ErrorState(
                title: l10n.reels_load_error,
                variant: ErrorStateVariant.network,
                onRetry: () => context.read<ReelsFeedCubit>().loadInitial(
                  locale: Localizations.localeOf(context),
                ),
              );
            case ReelsFeedStatus.empty:
              return EmptyState(
                icon: Icons.videocam_off_outlined,
                headline: l10n.reels_empty_headline,
                body: widget.emptyBody,
              );
            case ReelsFeedStatus.loaded:
            case ReelsFeedStatus.loadingMore:
              // The vertical feed sits edge-to-edge; the glass top bar
              // (title pill) floats over it inside a SafeArea so it clears
              // the status bar / notch in both orientations.
              return Stack(
                fit: StackFit.expand,
                children: [
                  _buildFeed(context, state.reels),
                  const _ReelsTopBar(),
                ],
              );
          }
        },
      ),
    );
  }

  Widget _buildFeed(BuildContext context, List<Reel> reels) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: reels.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final reel = reels[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ReelPlayer(
              controller: _controllers[index],
              posterUrl: reel.posterImageUrl,
              muted: _muted,
              muteHintVisible: index == _current && _muteHintVisible,
              posterSemanticLabel: AppLocalizations.of(context)!.image_unavailable,
              onToggleMute: _toggleMute,
            ),
            _ReelOverlay(reel: reel),
          ],
        );
      },
    );
  }
}

/// The floating glass top bar over the feed — a brand-tinted "Reels" title
/// pill drawn from the photo-overlay tokens so it lifts off the video in both
/// themes. Replaces the old transparent [AppBar] (matches the panorama-viewer
/// chrome idiom).
class _ReelsTopBar extends StatelessWidget {
  const _ReelsTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: GlassPill(
            icon: LucideIcons.clapperboard,
            label: l10n.reels_section_title,
          ),
        ),
      ),
    );
  }
}

/// The bottom overlay on each reel: a royal-blue price pill, the title, the
/// location, and a "View listing" CTA that routes to the listing's detail
/// page. Sits over a bottom-anchored scrim so the over-video text stays legible
/// on bright footage.
class _ReelOverlay extends StatelessWidget {
  const _ReelOverlay({required this.reel});

  final Reel reel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              colors.scrim,
              colors.scrim.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.xxxl,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reel.hasPrice) ...[
                  _PricePill(
                    label: l10n.priceWithCurrency(
                      reel.priceAmount!,
                      reel.priceCurrency!,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  reel.title.isEmpty ? '—' : reel.title,
                  style: styles.titleLarge.copyWith(color: colors.onPhoto),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (reel.locationLabel.isNotEmpty &&
                    reel.locationLabel != '—') ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.map_pin,
                        size: AppSpacing.md,
                        color: colors.onPhoto,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          reel.locationLabel,
                          style: styles.bodyMedium.copyWith(
                            color: colors.onPhoto,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: l10n.reels_view_listing,
                  icon: LucideIcons.arrow_right,
                  onPressed: () =>
                      context.push(AppRoutes.listingDetailsFor(reel.listingId)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The over-video price chip — a solid royal-blue ([colors.primary]) pill with
/// a price-tag glyph, lifted off the footage by the elevation token. Reads as
/// the brand's signal color rather than the neutral glass used elsewhere on the
/// reel, so the price is the first thing the eye lands on.
class _PricePill extends StatelessWidget {
  const _PricePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: appRadius(AppRadii.pill),
        boxShadow: elevation.level1,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.tag,
              size: AppSpacing.md,
              color: colors.onPrimary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: styles.labelLarge.copyWith(color: colors.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
