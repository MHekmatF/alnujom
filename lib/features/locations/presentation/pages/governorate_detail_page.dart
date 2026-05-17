import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
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

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: const [LocaleToggleAction()],
          ),
          floatingActionButton: FloatingActionButton(
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
            child: const Icon(Icons.add),
          ),
          body: switch (state) {
            GovernorateDetailLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            GovernorateDetailError(:final message) => Center(
              child: Text(message, textAlign: TextAlign.center),
            ),
            GovernorateDetailLoaded(:final governorate, :final cities) =>
              RefreshIndicator(
                onRefresh: () async => context
                    .read<GovernorateDetailBloc>()
                    .add(const GovernorateDetailRefreshRequested()),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
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
                        TextButton.icon(
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
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l10n.editAffordance),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Cities list
                    if (cities.isEmpty)
                      Center(child: Text(l10n.addCityButton))
                    else
                      ...cities.map(
                        (summary) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: CityCard(
                            summary: summary,
                            onTap: () => context.go(
                              '${AppRoutes.locationsAdmin}/$governorateId'
                              '/cities/${summary.city.id}',
                            ),
                            onEdit: () => _openCityForm(
                              context,
                              mode: 'edit',
                              id: summary.city.id,
                            ),
                            onToggleActive: () =>
                                _toggleCityActive(context, summary),
                            onDelete: summary.city.isSystem
                                ? null
                                : () => _confirmDeleteCity(context, summary),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
