// lib/features/agency/presentation/pages/agency_analytics_page.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T057).
// Bounded analytics: active member count + listing-by-status counters.
// Phase 2 tokens only; all strings via AppLocalizations.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/staggered_list_item.dart';
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
      // Batch-2: the id is threaded through so the error body can offer a Retry
      // calling the very same load(agencyId).
      child: _AgencyAnalyticsView(agencyId: agencyId),
    );
  }
}

class _AgencyAnalyticsView extends StatelessWidget {
  const _AgencyAnalyticsView({required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    // Render counters in the active locale's numerals (Arabic-Indic in ar).
    final locale = Localizations.localeOf(context);

    return DcCrownScaffold(
      title: l10n.agency_analytics_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: BlocBuilder<AgencyAnalyticsCubit, AgencyAnalyticsState>(
        builder: (context, state) {
          return switch (state) {
            // Batch-2: full-screen spinner -> card-shaped skeleton; bare centred
            // Text error -> the shared ErrorState with a Retry.
            AgencyAnalyticsLoading() => const _AnalyticsSkeleton(),
            AgencyAnalyticsErrorState() => ErrorState(
              title: l10n.agency_generic_error,
              onRetry: () =>
                  context.read<AgencyAnalyticsCubit>().load(agencyId),
            ),
            AgencyAnalyticsLoaded(:final analytics) => ListView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              children: [
                StaggeredListItem(
                  index: 0,
                  child: _StatCard(
                    icon: LucideIcons.users,
                    label: l10n.agency_analytics_members(analytics.memberCount),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                StaggeredListItem(
                  index: 1,
                  child: _StatCard(
                    icon: LucideIcons.house,
                    label: l10n.agency_analytics_listings(
                      analytics.listingsByStatus.values.fold<int>(
                        0,
                        (sum, v) => sum + v,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Per-status breakdown rows on a single hairline card, so the
                // numbers read as one table rather than as loose lines.
                if (analytics.listingsByStatus.isNotEmpty)
                  StaggeredListItem(
                    index: 2,
                    child: AppSurface(
                      radius: AppRadii.lg,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        children: [
                          for (final entry
                              in analytics.listingsByStatus.entries)
                            Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key, style: styles.bodyLarge),
                                  Text(
                                    formatLocalizedNumber(entry.value, locale),
                                    style: styles.priceMedium,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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

/// Batch-2: the stock Material [Card] became the DS [AppSurface] with the
/// tinted-circle glyph used by every other internal row (ads, currencies,
/// locations), so the agency KPIs read as part of the same system.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return AppSurface(
      radius: AppRadii.lg,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.xxl + AppSpacing.lg,
            height: AppSpacing.xxl + AppSpacing.lg,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer,
            ),
            child: Icon(
              icon,
              color: colors.onPrimaryContainer,
              size: AppSpacing.xl,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: styles.titleMedium)),
        ],
      ),
    );
  }
}

/// Shimmer placeholder cards shown while the agency analytics load.
class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => const SizedBox(
        height: AppSpacing.xxxl + AppSpacing.xl,
        child: LoadingState.card(),
      ),
    );
  }
}
