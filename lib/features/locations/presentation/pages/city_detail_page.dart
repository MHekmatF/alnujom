import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/area.dart';
import '../../domain/usecases/delete_area.dart';
import '../../domain/usecases/update_area.dart';
import '../bloc/city_detail_bloc.dart';
import '../widgets/area_card.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/hidden_badge.dart';

class CityDetailPage extends StatelessWidget {
  const CityDetailPage({
    super.key,
    required this.governorateId,
    required this.cityId,
  });

  final String governorateId;
  final String cityId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CityDetailBloc>(
      create: (_) =>
          getIt<CityDetailBloc>()..add(CityDetailLoadRequested(cityId)),
      child: _CityDetailView(cityId: cityId),
    );
  }
}

class _CityDetailView extends StatelessWidget {
  const _CityDetailView({required this.cityId});

  final String cityId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return BlocBuilder<CityDetailBloc, CityDetailState>(
      builder: (context, state) {
        final title = state is CityDetailLoaded
            ? state.city.localizedName(locale)
            : l10n.cityDetailPageTitle;

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
            onPressed: () async {
              final result = await context.push<bool>(
                '${AppRoutes.locationsAdminForm}'
                '?mode=add&level=area&parentId=$cityId',
              );
              if (result == true && context.mounted) {
                context.read<CityDetailBloc>().add(
                  const CityDetailRefreshRequested(),
                );
              }
            },
            child: const Icon(LucideIcons.plus),
          ),
          body: switch (state) {
            CityDetailLoading() => const AppSpinner.page(),
            CityDetailError(:final message) => Center(
              child: Text(message, textAlign: TextAlign.center),
            ),
            CityDetailLoaded(:final city, :final governorate, :final areas) =>
              RefreshIndicator(
                onRefresh: () async => context.read<CityDetailBloc>().add(
                  const CityDetailRefreshRequested(),
                ),
                child: ListView(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  children: [
                    Row(
                      children: [
                        if (!city.isActive) ...[
                          const HiddenBadge(),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            l10n.cityDetailBreadcrumb(
                              governorate.localizedName(locale),
                              city.localizedName(locale),
                            ),
                            style: AppTextStyles.of(context).titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final result = await context.push<bool>(
                              '${AppRoutes.locationsAdminForm}'
                              '?mode=edit&level=city&id=$cityId',
                            );
                            if (result == true && context.mounted) {
                              context.read<CityDetailBloc>().add(
                                const CityDetailRefreshRequested(),
                              );
                            }
                          },
                          icon: const Icon(LucideIcons.pencil),
                          label: Text(l10n.editAffordance),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (areas.isEmpty)
                      Center(child: Text(l10n.addAreaButton))
                    else
                      ...areas.map(
                        (area) => Padding(
                          padding: const EdgeInsetsDirectional.only(
                            bottom: AppSpacing.sm,
                          ),
                          child: AreaCard(
                            area: area,
                            onEdit: () => _openAreaForm(
                              context,
                              mode: 'edit',
                              id: area.id,
                            ),
                            onToggleActive: () =>
                                _toggleAreaActive(context, area),
                            onDelete: () => _confirmDeleteArea(context, area),
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

  Future<void> _openAreaForm(
    BuildContext context, {
    required String mode,
    String? id,
  }) async {
    final params = StringBuffer('?mode=$mode&level=area');
    if (id != null) params.write('&id=$id');
    params.write('&parentId=$cityId');

    final result = await context.push<bool>(
      '${AppRoutes.locationsAdminForm}$params',
    );
    if (result == true && context.mounted) {
      context.read<CityDetailBloc>().add(const CityDetailRefreshRequested());
    }
  }

  Future<void> _toggleAreaActive(BuildContext context, Area area) async {
    try {
      await getIt<UpdateArea>()(area.id, isActive: !area.isActive);
      if (context.mounted) {
        context.read<CityDetailBloc>().add(const CityDetailRefreshRequested());
      }
    } on Object {
      // Refresh will reflect unchanged state if toggle failed
    }
  }

  Future<void> _confirmDeleteArea(BuildContext context, Area area) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: l10n.deleteConfirmTitle,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await getIt<DeleteArea>()(area.id);
      if (context.mounted) {
        context.read<CityDetailBloc>().add(const CityDetailRefreshRequested());
      }
    } on Object catch (error) {
      if (context.mounted) {
        AppToast.error(context, error.toString());
      }
    }
  }
}
