import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../core/widgets/staggered_list_item.dart';
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
            // Batch-2 a11y: the icon-only FAB had no accessible name.
            tooltip: l10n.addAreaButton,
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
            // Batch-2: full-screen spinner -> list-shaped skeleton; bare centred
            // Text error -> shared ErrorState with a Retry.
            CityDetailLoading() => const _AreasSkeleton(),
            CityDetailError(:final message) => ErrorState(
              title: l10n.locationsLoadFailed,
              message: message,
              onRetry: () => context.read<CityDetailBloc>().add(
                const CityDetailRefreshRequested(),
              ),
            ),
            CityDetailLoaded(:final city, :final governorate, :final areas) =>
              RefreshIndicator(
                onRefresh: () async => context.read<CityDetailBloc>().add(
                  const CityDetailRefreshRequested(),
                ),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                        // Batch-2: stock TextButton.icon -> DS AppButton text
                        // variant (48dp target, PressScale, token type).
                        AppButton(
                          label: l10n.editAffordance,
                          variant: AppButtonVariant.text,
                          icon: LucideIcons.pencil,
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
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (areas.isEmpty)
                      // Batch-2: a bare centred "Add area" string became a real
                      // EmptyState (glyph badge + headline + hint).
                      EmptyState(
                        icon: LucideIcons.map_pin,
                        headline: l10n.locationPickerNoAreasYet,
                        body: l10n.addAreaButton,
                      )
                    else
                      ...areas.indexed.map(
                        (entry) => Padding(
                          padding: const EdgeInsetsDirectional.only(
                            bottom: AppSpacing.sm,
                          ),
                          child: StaggeredListItem(
                            index: entry.$1,
                            child: AreaCard(
                              area: entry.$2,
                              onEdit: () => _openAreaForm(
                                context,
                                mode: 'edit',
                                id: entry.$2.id,
                              ),
                              onToggleActive: () =>
                                  _toggleAreaActive(context, entry.$2),
                              onDelete: () =>
                                  _confirmDeleteArea(context, entry.$2),
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

/// Shimmer placeholder rows shown while the areas list loads.
class _AreasSkeleton extends StatelessWidget {
  const _AreasSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const SizedBox(
        height: AppSpacing.xxxl + AppSpacing.xl,
        child: LoadingState.card(),
      ),
    );
  }
}
