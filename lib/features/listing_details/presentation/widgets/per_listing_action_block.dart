import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../features/favorites/presentation/bloc/favorites_cubit.dart';
import '../../../../features/reports/presentation/widgets/report_sheet.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 13 (spec/013-home-and-details) — Per-listing action block.
///
/// Favorite CTA rewired in Phase 17 (spec/017-favorites) to a live
/// `BlocSelector`-driven toggle with the anonymous-aware `FavoritesCubit`
/// branch. Report CTA rewired in Phase 18 (spec/018-reports-moderation) to
/// `_onReportTap`: anon → sign-in prompt + login route; signed-in → sheet.
///
/// Premium uplift v2 — the Share CTA is now LIVE: it opens the OS share sheet
/// (`share_plus`) with the listing title + price and a deep link to this
/// listing. [shareTitle] / [sharePrice] are supplied by the detail page (which
/// owns the localized title + formatted price); when absent the share text
/// falls back to the deep link alone.
class PerListingActionBlock extends StatelessWidget {
  const PerListingActionBlock({
    super.key,
    required this.listingId,
    this.shareTitle,
    this.sharePrice,
  });

  final String listingId;

  /// Localized listing title for the share payload (optional).
  final String? shareTitle;

  /// Pre-formatted primary price for the share payload (optional).
  final String? sharePrice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Favorite CTA — Phase 17 live toggle (Share + Report unchanged).
        BlocSelector<FavoritesCubit, FavoritesState, bool>(
          bloc: getIt<FavoritesCubit>(),
          selector: (s) => s.favoritedIds.contains(listingId),
          builder: (context, isFavorited) {
            return _ActionButton(
              icon: isFavorited ? Icons.favorite : Icons.favorite_border,
              label: isFavorited
                  ? l10n.favorite_unsave_label
                  : l10n.favorite_heart_label,
              onPressed: () => _onFavoriteTap(context),
            );
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        // Share CTA — live via share_plus (premium uplift v2).
        _ActionButton(
          icon: Icons.share_outlined,
          label: l10n.cta_share,
          onPressed: () => _onSharePressed(context),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Report CTA — Phase 18 live handler (FR-001/FR-034)
        _ActionButton(
          icon: Icons.flag_outlined,
          label: l10n.cta_report,
          onPressed: () => _onReportTap(context),
        ),
      ],
    );
  }

  /// Mirrors `FavoriteHeartButton._onTap` — anonymous branch shows prompt +
  /// routes to login; authenticated branch toggles via the shared singleton.
  void _onFavoriteTap(BuildContext context) {
    final cubit = getIt<FavoritesCubit>();
    if (!cubit.state.isSignedIn) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.favorite_sign_in_prompt)));
      context.push(AppRoutes.login);
      return;
    }
    cubit.toggle(listingId);
  }

  /// Phase 18 — anonymous branch: sign-in prompt snackbar + login route.
  /// Authenticated branch: open the ReportSheet modal bottom sheet.
  /// Mirrors `_onFavoriteTap` auth-state pattern (FR-001 / FR-034).
  void _onReportTap(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (getIt<AuthBloc>().state is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.report_sign_in_prompt)),
      );
      context.push(AppRoutes.login);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(listingId: listingId),
    );
  }

  /// Opens the OS share sheet with the listing title + price and a deep link
  /// to this listing. Composed from the (optional) [shareTitle] / [sharePrice]
  /// supplied by the detail page; always includes the canonical listing URL so
  /// the recipient can open it.
  Future<void> _onSharePressed(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final link = '$_shareLinkBase${AppRoutes.listingDetailsFor(listingId)}';

    final lines = <String>[
      if (shareTitle != null && shareTitle!.trim().isNotEmpty) shareTitle!.trim(),
      if (sharePrice != null && sharePrice!.trim().isNotEmpty) sharePrice!.trim(),
      link,
    ];
    final text = lines.join('\n');

    await Share.share(text, subject: l10n.listing_details_share_subject);
  }

  /// Canonical https base for shareable listing links. The Android manifest
  /// already declares an https VIEW intent; even without app-link verification
  /// the URL is meaningful and resolves to the listing in any browser.
  static const String _shareLinkBase = 'https://alnujom.app';
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: theme.textTheme.labelMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
