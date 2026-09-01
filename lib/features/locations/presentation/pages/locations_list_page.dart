import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/governorate_with_city_count.dart';
import '../../domain/usecases/count_governorate_dependents.dart';
import '../../domain/usecases/delete_governorate.dart';
import '../../domain/usecases/update_governorate.dart';
import '../bloc/locations_list_bloc.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/governorate_card.dart';

class LocationsListPage extends StatelessWidget {
  const LocationsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LocationsListBloc>(
      create: (_) => getIt<LocationsListBloc>()..add(const LoadRequested()),
      child: const _LocationsListView(),
    );
  }
}

class _LocationsListView extends StatelessWidget {
  const _LocationsListView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.locationsListPageTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      actions: const [LocaleToggleAction()],
      floatingActionButton: FloatingActionButton(
        // Batch-2 a11y: the icon-only FAB had no accessible name.
        tooltip: l10n.addGovernorateButton,
        onPressed: () async {
          final result = await context.push<bool>(
            '${AppRoutes.locationsAdminForm}?mode=add&level=governorate',
          );
          if (result == true && context.mounted) {
            context.read<LocationsListBloc>().add(const RefreshRequested());
          }
        },
        child: const Icon(LucideIcons.plus),
      ),
      body: BlocBuilder<LocationsListBloc, LocationsListState>(
        builder: (context, state) => switch (state) {
          LocationsListLoading() => const _LocationsListSkeleton(),
          // Batch-2: the bare centred Text error gains the shared ErrorState
          // treatment AND — new — a Retry affordance.
          LocationsListError(:final message) => ErrorState(
            title: l10n.locationsLoadFailed,
            message: message,
            onRetry: () =>
                context.read<LocationsListBloc>().add(const RefreshRequested()),
          ),
          LocationsListLoaded(:final governorates) =>
            governorates.isEmpty
                // Batch-2: the empty state echoed the page title ("Governorates")
                // as its only copy; now a real EmptyState pointing at the FAB.
                ? EmptyState(
                    icon: LucideIcons.map_pin,
                    headline: l10n.locationsListPageTitle,
                    body: l10n.addGovernorateButton,
                  )
                : RefreshIndicator(
                    onRefresh: () async => context
                        .read<LocationsListBloc>()
                        .add(const RefreshRequested()),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                      itemCount: governorates.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final summary = governorates[index];
                        return StaggeredListItem(
                          index: index,
                          child: GovernorateCard(
                            summary: summary,
                            onTap: () => context.go(
                              '${AppRoutes.locationsAdmin}/${summary.governorate.id}',
                            ),
                            onEdit: () => _openForm(
                              context,
                              mode: 'edit',
                              level: 'governorate',
                              id: summary.governorate.id,
                            ),
                            onToggleActive: () =>
                                _toggleActive(context, summary),
                            onDelete: summary.governorate.isSystem
                                ? null
                                : () => _confirmDelete(context, summary),
                          ),
                        );
                      },
                    ),
                  ),
        },
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context, {
    required String mode,
    required String level,
    String? id,
    String? parentId,
  }) async {
    final params = StringBuffer('?mode=$mode&level=$level');
    if (id != null) params.write('&id=$id');
    if (parentId != null) params.write('&parentId=$parentId');

    final result = await context.push<bool>(
      '${AppRoutes.locationsAdminForm}$params',
    );
    if (result == true && context.mounted) {
      context.read<LocationsListBloc>().add(const RefreshRequested());
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    GovernorateWithCityCount summary,
  ) async {
    try {
      await getIt<UpdateGovernorate>()(
        summary.governorate.id,
        isActive: !summary.governorate.isActive,
      );
      if (context.mounted) {
        context.read<LocationsListBloc>().add(const RefreshRequested());
      }
    } on Object {
      // Refresh will reflect unchanged state if toggle failed
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    GovernorateWithCityCount summary,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: l10n.deleteConfirmTitle,
      governorateDependsFuture: getIt<CountGovernorateDependents>().call(
        summary.governorate.id,
      ),
    );
    if (!confirmed || !context.mounted) return;

    try {
      await getIt<DeleteGovernorate>()(summary.governorate.id);
      if (context.mounted) {
        context.read<LocationsListBloc>().add(const RefreshRequested());
      }
    } on Object catch (error) {
      if (context.mounted) {
        AppToast.error(context, error.toString());
      }
    }
  }
}

/// Shimmer placeholder rows shown while the governorates list loads.
class _LocationsListSkeleton extends StatelessWidget {
  const _LocationsListSkeleton();

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
