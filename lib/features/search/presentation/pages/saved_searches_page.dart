// lib/features/search/presentation/pages/saved_searches_page.dart
//
// Phase 25 premium uplift — lists the current user's saved searches and lets
// them re-apply (navigate to /search seeded with the saved FilterState) or
// delete one. Anonymous users see the empty state (owner-only RLS yields no
// rows). Reuses EmptyState / ErrorState / LoadingState for branded states.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/count_filter_mode.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/entities/saved_search.dart';
import '../cubit/saved_searches_cubit.dart';

class SavedSearchesPage extends StatelessWidget {
  const SavedSearchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SavedSearchesCubit>(
      create: (_) => getIt<SavedSearchesCubit>()..load(),
      child: const _SavedSearchesView(),
    );
  }
}

class _SavedSearchesView extends StatelessWidget {
  const _SavedSearchesView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcCrownScaffold(
      title: l10n.search_saved_searches_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
        builder: (context, state) {
          return switch (state.status) {
            SavedSearchesStatus.initial ||
            SavedSearchesStatus.loading => const _SavedSearchesSkeleton(),
            SavedSearchesStatus.failure => ErrorState(
              title: l10n.search_saved_searches_error_title,
              variant: ErrorStateVariant.network,
              onRetry: () => context.read<SavedSearchesCubit>().load(),
            ),
            SavedSearchesStatus.success =>
              state.items.isEmpty
                  ? EmptyState(
                      icon: LucideIcons.bookmark,
                      headline: l10n.search_saved_searches_empty_title,
                      body: l10n.search_saved_searches_empty_subtitle,
                    )
                  : _SavedSearchesList(items: state.items),
          };
        },
      ),
    );
  }
}

class _SavedSearchesSkeleton extends StatelessWidget {
  const _SavedSearchesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
        child: SizedBox(
          height: AppSpacing.xxxl + AppSpacing.xxl,
          child: LoadingState.card(),
        ),
      ),
    );
  }
}

class _SavedSearchesList extends StatelessWidget {
  const _SavedSearchesList({required this.items});

  final List<SavedSearch> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      // +1 leading row for the alerts hint.
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const _SavedSearchAlertsHint();
        return _SavedSearchCard(savedSearch: items[index - 1]);
      },
    );
  }
}

/// A subtle one-line reassurance that the user will be alerted when a matching
/// property is posted (a DB trigger emits a `saved_search_match` notification).
class _SavedSearchAlertsHint extends StatelessWidget {
  const _SavedSearchAlertsHint();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppSpacing.md,
        start: AppSpacing.xs,
        end: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.bell_ring,
            size: AppSpacing.md,
            color: colors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.search_saved_searches_alerts_hint,
              style: styles.labelMedium.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedSearchCard extends StatelessWidget {
  const _SavedSearchCard({required this.savedSearch});

  final SavedSearch savedSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();
    final summary = _filterSummary(savedSearch.filters, l10n);
    final dateLabel = DateFormat.yMMMd(locale).format(savedSearch.createdAt);

    return PressScale(
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
        child: Material(
          color: colors.card,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: appRadius(AppRadii.lg),
            side: BorderSide(color: colors.outline),
          ),
          child: InkWell(
            onTap: () => _apply(context, savedSearch.filters),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: AppSpacing.xxl + AppSpacing.sm,
                    height: AppSpacing.xxl + AppSpacing.sm,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: appRadius(AppRadii.md),
                    ),
                    child: Icon(
                      LucideIcons.bookmark,
                      color: colors.onPrimaryContainer,
                      size: AppSpacing.lg,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          savedSearch.label,
                          style: styles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          summary.isEmpty
                              ? l10n.search_saved_searches_all_listings
                              : summary,
                          style: styles.bodyMedium.copyWith(
                            color: colors.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          dateLabel,
                          style: styles.labelMedium.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.search_saved_searches_delete,
                    icon: Icon(LucideIcons.trash_2, color: colors.error),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _apply(BuildContext context, FilterState filters) {
    // Hand off to the search route seeded with the saved filters.
    context.go(AppRoutes.search, extra: filters);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<SavedSearchesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      // Cancel maybePops with null — like the old `false`, it fails the
      // `confirmed == true` gate, so the return semantics are unchanged.
      builder: (dialogContext) => AppDialog(
        title: l10n.search_saved_searches_delete_title,
        message: l10n.search_saved_searches_delete_body,
        icon: LucideIcons.trash_2,
        variant: AppDialogVariant.destructive,
        cancelLabel: l10n.search_save_search_cancel,
        actionLabel: l10n.search_saved_searches_delete,
        onAction: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed == true) {
      await cubit.delete(savedSearch.id);
    }
  }

  /// A short, localized summary of the saved filters for the card subtitle.
  String _filterSummary(FilterState f, AppLocalizations l10n) {
    final parts = <String>[];
    if (f.query != null && f.query!.isNotEmpty) parts.add('"${f.query}"');
    if (f.purpose != null) parts.add(_purposeLabel(f.purpose!, l10n));
    if (f.propertyType != null) {
      parts.add(_propertyTypeLabel(f.propertyType!, l10n));
    }
    if (f.governorateId != null || f.cityId != null || f.areaId != null) {
      parts.add(l10n.search_filter_location_label);
    }
    if (f.priceMin != null || f.priceMax != null) {
      parts.add(l10n.search_filter_price_range_label);
    }
    if (f.rooms != null) {
      final suffix = f.roomsMode == CountFilterMode.atLeast ? '+' : '';
      parts.add('${l10n.search_filter_rooms_label}: ${f.rooms}$suffix');
    }
    if (f.bathrooms != null) {
      parts.add('${l10n.search_filter_bathrooms_label}: ${f.bathrooms}');
    }
    if (f.areaSizeMin != null || f.areaSizeMax != null) {
      parts.add(l10n.search_filter_area_size_label);
    }
    return parts.join(' · ');
  }

  String _purposeLabel(ListingPurpose p, AppLocalizations l10n) {
    switch (p) {
      case ListingPurpose.sale:
        return l10n.listingPurposeSale;
      case ListingPurpose.rent:
        return l10n.listingPurposeRent;
      case ListingPurpose.dailyRent:
        return l10n.listingPurposeDailyRent;
      case ListingPurpose.investment:
        return l10n.listingPurposeInvestment;
    }
  }

  String _propertyTypeLabel(PropertyType t, AppLocalizations l10n) {
    switch (t) {
      case PropertyType.apartment:
        return l10n.propertyTypeApartment;
      case PropertyType.villa:
        return l10n.propertyTypeVilla;
      case PropertyType.land:
        return l10n.propertyTypeLand;
      case PropertyType.shop:
        return l10n.propertyTypeShop;
      case PropertyType.office:
        return l10n.propertyTypeOffice;
      case PropertyType.farm:
        return l10n.propertyTypeFarm;
      case PropertyType.warehouse:
        return l10n.propertyTypeWarehouse;
      case PropertyType.other:
        return l10n.propertyTypeOther;
    }
  }
}
