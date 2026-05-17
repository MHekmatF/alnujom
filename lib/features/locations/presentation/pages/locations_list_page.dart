import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.locationsListPageTitle),
        actions: const [LocaleToggleAction()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>(
            '${AppRoutes.locationsAdminForm}?mode=add&level=governorate',
          );
          if (result == true && context.mounted) {
            context.read<LocationsListBloc>().add(const RefreshRequested());
          }
        },
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<LocationsListBloc, LocationsListState>(
        builder: (context, state) => switch (state) {
          LocationsListLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          LocationsListError(:final message) => Center(
            child: Text(message, textAlign: TextAlign.center),
          ),
          LocationsListLoaded(:final governorates) =>
            governorates.isEmpty
                ? Center(child: Text(l10n.locationsListPageTitle))
                : RefreshIndicator(
                    onRefresh: () async => context
                        .read<LocationsListBloc>()
                        .add(const RefreshRequested()),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: governorates.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final summary = governorates[index];
                        return GovernorateCard(
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
                          onToggleActive: () => _toggleActive(context, summary),
                          onDelete: summary.governorate.isSystem
                              ? null
                              : () => _confirmDelete(context, summary),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
