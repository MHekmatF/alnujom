import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/city_with_area_count.dart';
import '../../domain/usecases/count_city_dependents.dart';
import '../../domain/usecases/delete_city.dart';
import '../../domain/usecases/update_city.dart';
import '../bloc/governorate_detail_bloc.dart';
import '../widgets/city_card.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/hidden_badge.dart';
import '../widgets/system_row_badge.dart';

class GovernorateDetailPage extends StatelessWidget {
  const GovernorateDetailPage({super.key, required this.governorateId});

  final String governorateId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GovernorateDetailBloc>(
      create: (_) =>
          getIt<GovernorateDetailBloc>()
            ..add(GovernorateDetailLoadRequested(governorateId)),
      child: _GovernorateDetailView(governorateId: governorateId),
    );
  }
}

class _GovernorateDetailView extends StatelessWidget {
  const _GovernorateDetailView({required this.governorateId});

  final String governorateId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<GovernorateDetailBloc, GovernorateDetailState>(
      builder: (context, state) {
        final title = state is GovernorateDetailLoaded
            ? state.governorate.localizedName(Localizations.localeOf(context))
            : l10n.governorateDetailPageTitle;

        return DcCrownScaffold(
          title: title,
          dense: true,
          leading: DcCrownIconButton(
            icon: Icons.arrow_forward,
            onTap: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.shellHome),
          ),
          actions: const [LocaleToggleAction()],
          floatingActionButton: FloatingActionButton(
            // Batch-2 a11y: the icon-only FAB had no accessible name.
            tooltip: l10n.addCityButton,
            onPressed: () async {
              final result = await context.push<bool>(
                '${AppRoutes.locationsAdminForm}'
                '?mode=add&level=city&parentId=$governorateId',
              );
              if (result == true && context.mounted) {
                context.read<GovernorateDetailBloc>().add(
                  const GovernorateDetailRefreshRequested(),
                );
              }
            },
            child: const Icon(LucideIcons.plus),
          ),
          body: switch (state) {
            // Batch-2: a full-screen spinner became a list-shaped skeleton, the
            // consumer convention for list surfaces.
            GovernorateDetailLoading() => const _CitiesSkeleton(),
            // Batch-2: bare centred Text -> shared ErrorState + a Retry.
            GovernorateDetailError(:final message) => ErrorState(
              title: l10n.locationsLoadFailed,
              message: message,
              onRetry: () => context.read<GovernorateDetailBloc>().add(
                const GovernorateDetailRefreshRequested(),
              ),
            ),
            GovernorateDetailLoaded(:final governorate, :final cities) =>
              RefreshIndicator(
                onRefresh: () async => context
                    .read<GovernorateDetailBloc>()
                    .add(const GovernorateDetailRefreshRequested()),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  children: [
                    // Governorate header
                    Row(
                      children: [
                        if (governorate.isSystem) const SystemRowBadge(),
                        if (!governorate.isActive) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const HiddenBadge(),
                        ],
                        const Spacer(),
                        // Batch-2: stock TextButton.icon -> the DS AppButton
                        // text variant (48dp target, PressScale, token type).
                        AppButton(
                          label: l10n.editAffordance,
                          variant: AppButtonVariant.text,
                          icon: LucideIcons.pencil,
                          onPressed: () async {
                            final result = await context.push<bool>(
                              '${AppRoutes.locationsAdminForm}'
                              '?mode=edit&level=governorate&id=$governorateId',
                            );
                            if (result == true && context.mounted) {
                              context.read<GovernorateDetailBloc>().add(
                                const GovernorateDetailRefreshRequested(),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Cities list
                    if (cities.isEmpty)
                      // Batch-2: a bare centred "Add city" string became a real
                      // EmptyState (glyph badge + headline + hint).
                      EmptyState(
                        icon: LucideIcons.building_2,
                        headline: l10n.cityDetailPageTitle,
                        body: l10n.addCityButton,
                      )
                    else
                      ...cities.indexed.map(
                        (entry) => Padding(
                          padding: const EdgeInsetsDirectional.only(
                            bottom: AppSpacing.sm,
                          ),
                          child: StaggeredListItem(
                            index: entry.$1,
                            child: CityCard(
                              summary: entry.$2,
                              onTap: () => context.go(
                                '${AppRoutes.locationsAdmin}/$governorateId'
                                '/cities/${entry.$2.city.id}',
                              ),
                              onEdit: () => _openCityForm(
                                context,
                                mode: 'edit',
                                id: entry.$2.city.id,
                              ),
                              onToggleActive: () =>
                                  _toggleCityActive(context, entry.$2),
                              onDelete: entry.$2.city.isSystem
                                  ? null
                                  : () => _confirmDeleteCity(context, entry.$2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          },
        );
      },
    );
  }

  Future<void> _openCityForm(
    BuildContext context, {
    required String mode,
    String? id,
  }) async {
    final params = StringBuffer('?mode=$mode&level=city');
    if (id != null) params.write('&id=$id');
    params.write('&parentId=$governorateId');

    final result = await context.push<bool>(
      '${AppRoutes.locationsAdminForm}$params',
    );
    if (result == true && context.mounted) {
      context.read<GovernorateDetailBloc>().add(
        const GovernorateDetailRefreshRequested(),
      );
    }
  }

  Future<void> _toggleCityActive(
    BuildContext context,
    CityWithAreaCount summary,
  ) async {
    try {
      await getIt<UpdateCity>()(
        summary.city.id,
        isActive: !summary.city.isActive,
      );
      if (context.mounted) {
        context.read<GovernorateDetailBloc>().add(
          const GovernorateDetailRefreshRequested(),
        );
      }
    } on Object {
      // Refresh will reflect unchanged state if toggle failed
    }
  }

  Future<void> _confirmDeleteCity(
    BuildContext context,
    CityWithAreaCount summary,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: l10n.deleteConfirmTitle,
      cityDependsFuture: getIt<CountCityDependents>().call(summary.city.id),
    );
    if (!confirmed || !context.mounted) return;

    try {
      await getIt<DeleteCity>()(summary.city.id);
      if (context.mounted) {
        context.read<GovernorateDetailBloc>().add(
          const GovernorateDetailRefreshRequested(),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        AppToast.error(context, error.toString());
      }
    }
  }
}

/// Shimmer placeholder rows shown while the cities list loads.
class _CitiesSkeleton extends StatelessWidget {
  const _CitiesSkeleton();

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
