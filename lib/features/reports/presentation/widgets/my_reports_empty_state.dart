// lib/features/reports/presentation/widgets/my_reports_empty_state.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T044).
// Phase polish (Impeccable) — uses the shared EmptyState so it teaches the
// interface (guiding subtext + a "Browse listings" CTA) and stays consistent.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';

/// Shown when the user has no submitted reports (FR-022): an illustration, the
/// headline, guiding subtext, and a CTA back to the feed.
class MyReportsEmptyState extends StatelessWidget {
  const MyReportsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return EmptyState(
      illustration: Icon(
        Icons.flag_outlined,
        size: AppSpacing.xxxl * 2,
        color: scheme.onSurfaceVariant,
      ),
      headline: l10n.reports_my_empty_state,
      body: l10n.reports_my_empty_body,
      ctaLabel: l10n.action_browse_listings,
      onCtaPressed: () => context.go(AppRoutes.home),
    );
  }
}
