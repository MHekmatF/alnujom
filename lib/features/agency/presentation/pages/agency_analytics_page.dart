// lib/features/agency/presentation/pages/agency_analytics_page.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T057).
// Bounded analytics: active member count + listing-by-status counters.
// Phase 2 tokens only; all strings via AppLocalizations.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../bloc/agency_analytics_cubit.dart';

class AgencyAnalyticsPage extends StatelessWidget {
  const AgencyAnalyticsPage({super.key, required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgencyAnalyticsCubit>(
      create: (_) => getIt<AgencyAnalyticsCubit>()..load(agencyId),
      child: const _AgencyAnalyticsView(),
    );
  }
}

class _AgencyAnalyticsView extends StatelessWidget {
  const _AgencyAnalyticsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    // Render counters in the active locale's numerals (Arabic-Indic in ar).
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(
        leading: const DeepLinkAwareBackButton(),
        title: Text(l10n.agency_analytics_title),
      ),
      body: BlocBuilder<AgencyAnalyticsCubit, AgencyAnalyticsState>(
        builder: (context, state) {
          return switch (state) {
            AgencyAnalyticsLoading() => const AppSpinner.page(),
            AgencyAnalyticsErrorState() => Center(
              child: Text(l10n.agency_generic_error),
            ),
            AgencyAnalyticsLoaded(:final analytics) => ListView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              children: [
                _StatCard(
                  icon: Icons.group_outlined,
                  label: l10n.agency_analytics_members(analytics.memberCount),
                ),
                const SizedBox(height: AppSpacing.md),
                _StatCard(
                  icon: Icons.list_alt_outlined,
                  label: l10n.agency_analytics_listings(
                    analytics.listingsByStatus.values.fold<int>(
                      0,
                      (sum, v) => sum + v,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final entry in analytics.listingsByStatus.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key, style: styles.bodyLarge),
                        Text(
                          formatLocalizedNumber(entry.value, locale),
                          style: styles.titleMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          };
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: styles.titleMedium),
          ],
        ),
      ),
    );
  }
}
