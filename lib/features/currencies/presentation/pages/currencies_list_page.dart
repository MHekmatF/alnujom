import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/currencies_repository_impl.dart'
    show CurrenciesFailure;
import '../../domain/entities/currency.dart';
import '../../domain/usecases/count_dependent_exchange_rates.dart';
import '../../domain/usecases/delete_currency.dart';
import '../bloc/currencies_list_bloc.dart';
import '../widgets/currency_card.dart';
import '../widgets/delete_currency_confirmation_dialog.dart';

class CurrenciesListPage extends StatelessWidget {
  const CurrenciesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CurrenciesListBloc>(
      create: (_) => getIt<CurrenciesListBloc>()..add(const LoadCurrencies()),
      child: const _CurrenciesListView(),
    );
  }
}

class _CurrenciesListView extends StatelessWidget {
  const _CurrenciesListView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcCrownScaffold(
      title: l10n.currenciesPageTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _openSetRate(context),
          icon: const Icon(LucideIcons.chart_line),
          label: Text(l10n.setNewRateButton),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.of(context).onBrandHeader,
          ),
        ),
        const LocaleToggleAction(),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>(
            '${AppRoutes.currenciesAdminForm}?mode=create',
          );
          if (result == true && context.mounted) {
            context.read<CurrenciesListBloc>().add(const RefreshCurrencies());
          }
        },
        child: const Icon(LucideIcons.plus),
      ),
      body: BlocBuilder<CurrenciesListBloc, CurrenciesListState>(
        builder: (context, state) => switch (state) {
          CurrenciesListInitial() ||
          CurrenciesListLoading() => const _CurrenciesSkeleton(),
          CurrenciesListError(:final reason) => Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Text(
                _errorText(l10n, reason),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          CurrenciesListLoaded(:final currencies) => RefreshIndicator(
            onRefresh: () async => context.read<CurrenciesListBloc>().add(
              const RefreshCurrencies(),
            ),
            child: ListView.separated(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              itemCount: currencies.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final summary = currencies[index];
                return CurrencyCard(
                  summary: summary,
                  locale: Localizations.localeOf(context),
                  onEdit: () => _openForm(context, summary.currency.code),
                  onViewHistory: () => context.go(
                    '${AppRoutes.currenciesAdmin}/${summary.currency.code}/history',
                  ),
                  onDelete: summary.currency.isSystem
                      ? null
                      : () => _confirmDelete(context, summary.currency),
                );
              },
            ),
          ),
        },
      ),
    );
  }

  Future<void> _openSetRate(BuildContext context) async {
    final result = await context.push<bool>(AppRoutes.currenciesAdminSetRate);
    if (result == true && context.mounted) {
      context.read<CurrenciesListBloc>().add(const RefreshCurrencies());
    }
  }

  Future<void> _openForm(BuildContext context, String code) async {
    final result = await context.push<bool>(
      '${AppRoutes.currenciesAdminForm}?mode=edit&code=$code',
    );
    if (result == true && context.mounted) {
      context.read<CurrenciesListBloc>().add(CurrencyMutated(code));
    }
  }

  Future<void> _confirmDelete(BuildContext context, Currency currency) async {
    final count = await getIt<CountDependentExchangeRates>()(currency.code);
    if (!context.mounted) return;
    final confirmed = await showDeleteCurrencyConfirmationDialog(
      context,
      currency: currency,
      exchangeRatesCount: count,
      listingPricesCount: 0,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await getIt<DeleteCurrency>()(currency.code);
      if (context.mounted) {
        context.read<CurrenciesListBloc>().add(CurrencyMutated(currency.code));
      }
    } on CurrenciesFailure catch (error) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppToast.error(context, _errorText(l10n, error.code));
      }
    } on Object catch (_) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppToast.error(context, l10n.errorCurrencyUnknown);
      }
    }
  }

  String _errorText(AppLocalizations l10n, String reason) {
    return switch (reason) {
      'permission_denied' => l10n.errorPermissionDenied,
      'duplicate_code' => l10n.errorDuplicateCode,
      'system_immutable' => l10n.errorSystemCurrencyImmutable,
      'has_references' => l10n.errorCurrencyHasReferences,
      'rate_must_be_positive' => l10n.rateMustBePositiveError,
      'base_equals_target' => l10n.baseEqualsTargetError,
      'display_decimals_range' => l10n.displayDecimalsRangeError,
      'validation_failed' => l10n.errorValidationFailed,
      _ => l10n.errorCurrencyUnknown,
    };
  }
}

/// Shimmer placeholder rows shown while the currencies list loads.
class _CurrenciesSkeleton extends StatelessWidget {
  const _CurrenciesSkeleton();

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
