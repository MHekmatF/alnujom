// lib/features/agency/presentation/pages/agency_listings_page.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T057).
// Paginated list of the agency's listings (v_listings_public, approved-only).
// Mirrors MyReportsPage's RefreshIndicator + ListView + near-end load-more.
// Phase 2 tokens only; all strings via AppLocalizations.
import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../bloc/agency_listings_bloc.dart';

class AgencyListingsPage extends StatelessWidget {
  const AgencyListingsPage({super.key, required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgencyListingsBloc>(
      create: (_) =>
          getIt<AgencyListingsBloc>()..add(AgencyListingsOpened(agencyId)),
      child: _AgencyListingsView(agencyId: agencyId),
    );
  }
}

class _AgencyListingsView extends StatelessWidget {
  const _AgencyListingsView({required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.agency_listings_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: BlocBuilder<AgencyListingsBloc, AgencyListingsState>(
        builder: (context, state) {
          return switch (state) {
            // Batch-2: full-screen spinner -> list-shaped skeleton; bare centred
            // Texts -> the shared ErrorState (now with a Retry) and EmptyState.
            AgencyListingsLoading() => const _AgencyListingsSkeleton(),
            AgencyListingsError() => ErrorState(
              title: l10n.agency_generic_error,
              onRetry: () => context.read<AgencyListingsBloc>().add(
                AgencyListingsRefreshRequested(agencyId),
              ),
            ),
            AgencyListingsLoaded(:final items, :final hasMore) =>
              items.isEmpty
                  ? EmptyState(
                      icon: LucideIcons.house,
                      headline: l10n.agency_listings_empty,
                    )
                  : _ListBody(
                      agencyId: agencyId,
                      items: items,
                      hasMore: hasMore,
                    ),
          };
        },
      ),
    );
  }
}

class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.agencyId,
    required this.items,
    required this.hasMore,
  });

  final String agencyId;
  final List<Map<String, dynamic>> items;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<AgencyListingsBloc>().add(
          AgencyListingsRefreshRequested(agencyId),
        );
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= (items.length * 0.8).floor() && hasMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<AgencyListingsBloc>().add(
                AgencyListingsMoreLoaded(agencyId),
              );
            });
          }
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsetsDirectional.all(AppSpacing.lg),
              child: AppSpinner(),
            );
          }
          return StaggeredListItem(
            index: index,
            child: _ListingCard(row: items[index]),
          );
        },
      ),
    );
  }
}

/// Shimmer placeholder rows shown while the agency listings load.
class _AgencyListingsSkeleton extends StatelessWidget {
  const _AgencyListingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const SizedBox(
        height: AppSpacing.xxxl + AppSpacing.xxl,
        child: LoadingState.card(),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final id = row['id'] as String?;
    final title = (row['title'] as String?) ?? '';
    final amount = row['primary_amount'];
    final currency = (row['primary_currency'] as String?) ?? '';
    final imagePath = row['main_image_path'] as String?;

    // Batch-2: the stock Material [Card]+[InkWell] became the DS [AppSurface]
    // (card fill + hairline + radius-lg) under a [PressScale], matching the
    // My-Reports / publisher listing rows. The price now uses the `priceMedium`
    // token instead of a muted body line.
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: PressScale(
        enabled: id != null,
        child: AppSurface(
          radius: AppRadii.lg,
          onTap: id == null
              ? null
              : () => context.push(AppRoutes.listingDetailsFor(id)),
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: MergeSemantics(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: appRadius(AppRadii.md),
                  child: SizedBox(
                    width: AppSpacing.xxxl + AppSpacing.xl,
                    height: AppSpacing.xxxl + AppSpacing.xl,
                    child: imagePath != null && imagePath.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imagePath,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                ColoredBox(color: colors.surfaceVariant),
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: colors.surfaceVariant,
                              child: Icon(
                                LucideIcons.image_off,
                                color: colors.textMuted,
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: colors.surfaceVariant,
                            child: Icon(
                              LucideIcons.image,
                              color: colors.textMuted,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? '—' : title,
                        style: styles.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (amount != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          MoneyFormatter.formatAmount(
                            amount as num,
                            currency,
                            locale: Localizations.localeOf(context),
                          ),
                          style: styles.priceMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
