import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/currency.dart';
import '../../domain/usecases/list_currencies.dart';
import '../bloc/exchange_rate_history_bloc.dart';
import '../widgets/exchange_rate_row.dart';

class ExchangeRateHistoryPage extends StatelessWidget {
  const ExchangeRateHistoryPage({required this.baseCurrencyCode, super.key});

  final String baseCurrencyCode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExchangeRateHistoryBloc>(
      create: (_) =>
          getIt<ExchangeRateHistoryBloc>()
            ..add(LoadHistory(baseCurrency: baseCurrencyCode)),
      child: _ExchangeRateHistoryView(baseCurrencyCode: baseCurrencyCode),
    );
  }
}

class _ExchangeRateHistoryView extends StatefulWidget {
  const _ExchangeRateHistoryView({required this.baseCurrencyCode});

  final String baseCurrencyCode;

  @override
  State<_ExchangeRateHistoryView> createState() =>
      _ExchangeRateHistoryViewState();
}

class _ExchangeRateHistoryViewState extends State<_ExchangeRateHistoryView> {
  late final Future<List<Currency>> _currenciesFuture;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currenciesFuture = getIt<ListCurrencies>()(activeOnly: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcCrownScaffold(
      title: l10n.exchangeRateHistoryPageTitleFor(widget.baseCurrencyCode),
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      actions: [
        IconButton(
          onPressed: () => context.push(
            '${AppRoutes.currenciesAdminSetRate}?base=${widget.baseCurrencyCode}',
          ),
          icon: Icon(
            LucideIcons.chart_line,
            color: AppColors.of(context).onBrandHeader,
          ),
          tooltip: l10n.setNewRateButton,
        ),
        const LocaleToggleAction(),
      ],
      body: FutureBuilder<List<Currency>>(
        future: _currenciesFuture,
        builder: (context, snapshot) {
          final currencies = snapshot.data ?? const <Currency>[];
          return BlocBuilder<ExchangeRateHistoryBloc, ExchangeRateHistoryState>(
            builder: (context, state) => switch (state) {
              ExchangeRateHistoryInitial() ||
              ExchangeRateHistoryLoading() => const _HistorySkeleton(),
              ExchangeRateHistoryError() => _HistoryErrorView(
                state: state,
                baseCurrencyCode: widget.baseCurrencyCode,
              ),
              ExchangeRateHistoryLoaded() => _HistoryLoadedView(
                state: state,
                currencies: currencies,
                scrollController: _scrollController,
              ),
              ExchangeRateHistoryLoadingMore(:final previous) =>
                _HistoryLoadedView(
                  state: previous,
                  currencies: currencies,
                  scrollController: _scrollController,
                  loadingMore: true,
                ),
            },
          );
        },
      ),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<ExchangeRateHistoryBloc>().add(const LoadMore());
    }
  }
}

class _HistoryErrorView extends StatelessWidget {
  const _HistoryErrorView({
    required this.state,
    required this.baseCurrencyCode,
  });

  final ExchangeRateHistoryError state;
  final String baseCurrencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Batch-2: the ad-hoc Text + AppButton column became the shared ErrorState
    // (glyph badge + tonal Retry). Same retry event, unchanged.
    return ErrorState(
      title: _errorText(l10n, state.code),
      onRetry: () => context.read<ExchangeRateHistoryBloc>().add(
        LoadHistory(
          baseCurrency: baseCurrencyCode,
          targetFilter: state.targetFilter,
        ),
      ),
    );
  }

  String _errorText(AppLocalizations l10n, String code) {
    return switch (code) {
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

class _HistoryLoadedView extends StatelessWidget {
  const _HistoryLoadedView({
    required this.state,
    required this.currencies,
    required this.scrollController,
    this.loadingMore = false,
  });

  final ExchangeRateHistoryLoaded state;
  final List<Currency> currencies;
  final ScrollController scrollController;
  final bool loadingMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final targetCurrencies = currencies
        .where((currency) => currency.code != state.baseCurrency)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loadingMore)
          LinearProgressIndicator(
            minHeight: AppSpacing.xxs,
            color: colors.primary,
            backgroundColor: colors.surfaceVariant,
          ),
        Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.targetCurrencyFilterLabel,
                style: styles.labelMedium.copyWith(color: colors.textMuted),
              ),
              // Batch-2: FilterChip -> ChoiceChip + selection haptic, matching
              // the consumer StatusFilterChipRow idiom. Both already inherit the
              // DS chipTheme; the swap is for one consistent chip family.
              _TargetChip(
                label: l10n.targetCurrencyAnyLabel,
                selected: state.targetFilter == null,
                onSelected: () => context.read<ExchangeRateHistoryBloc>().add(
                  const TargetFilterChanged(null),
                ),
              ),
              for (final currency in targetCurrencies)
                _TargetChip(
                  label: currency.code,
                  selected: state.targetFilter == currency.code,
                  onSelected: () => context.read<ExchangeRateHistoryBloc>().add(
                    TargetFilterChanged(currency.code),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: state.rates.isEmpty
              // Batch-2: bare centred Text -> shared EmptyState.
              ? EmptyState(
                  icon: LucideIcons.chart_line,
                  headline: l10n.noRatesYet,
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.lg,
                    end: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                  ),
                  itemCount: state.rates.length + (loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index >= state.rates.length) {
                      return const Padding(
                        padding: EdgeInsetsDirectional.all(AppSpacing.md),
                        child: AppSpinner(),
                      );
                    }
                    return StaggeredListItem(
                      index: index,
                      child: ExchangeRateRow(exchangeRate: state.rates[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A selectable target-currency filter chip (DS `chipTheme` + selection haptic).
class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onSelected();
      },
    );
  }
}

/// Shimmer placeholder rows shown while the rate history loads.
class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

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
