import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../features/reports/presentation/widgets/report_sheet.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 13 (spec/013-home-and-details) — Per-listing action block.
///
/// Report CTA rewired in Phase 18 (spec/018-reports-moderation) to
/// `_onReportTap`: anon → sign-in prompt + login route; signed-in → sheet.
///
/// Premium uplift v2 — the Share CTA is now LIVE: it opens the OS share sheet
/// (`share_plus`) with the listing title + price and a deep link to this
/// listing. [shareTitle] / [sharePrice] are supplied by the detail page (which
/// owns the localized title + formatted price); when absent the share text
/// falls back to the deep link alone.
///
/// Phase 35 (035-redesign-ground-up) craft pass — the duplicate Favorite CTA
/// was removed (favoriting lives on the listing-card / gallery heart), and
/// Share + Report are demoted to small quiet text buttons in one row instead
/// of three equal outlined buttons. Handlers unchanged.
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

    // Quiet secondary utilities — two small text buttons in one row (the
    // Favorite toggle lives on the listing-card / gallery heart, not here).
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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

  /// Phase 18 — anonymous branch: sign-in prompt snackbar + login route.
  /// Authenticated branch: open the ReportSheet modal bottom sheet.
  /// Mirrors the favorites auth-state pattern (FR-001 / FR-034).
  void _onReportTap(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (getIt<AuthBloc>().state is! Authenticated) {
      AppToast.warning(context, l10n.report_sign_in_prompt);
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
      if (shareTitle != null && shareTitle!.trim().isNotEmpty)
        shareTitle!.trim(),
      if (sharePrice != null && sharePrice!.trim().isNotEmpty)
        sharePrice!.trim(),
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

    // Small quiet text button (035 craft pass) — was an Expanded outlined
    // button when this row held three equal CTAs.
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: AppSpacing.lg),
      label: Text(
        label,
        style: theme.textTheme.labelMedium,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
