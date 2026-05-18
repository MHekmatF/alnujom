import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.exchangeRateHistoryPageTitleFor(widget.baseCurrencyCode),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(
              '${AppRoutes.currenciesAdminSetRate}?base=${widget.baseCurrencyCode}',
            ),
            icon: const Icon(Icons.add_chart),
            label: Text(l10n.setNewRateButton),
          ),
          const LocaleToggleAction(),
        ],
      ),
      body: FutureBuilder<List<Currency>>(
        future: _currenciesFuture,
        builder: (context, snapshot) {
          final currencies = snapshot.data ?? const <Currency>[];
          return BlocBuilder<ExchangeRateHistoryBloc, ExchangeRateHistoryState>(
            builder: (context, state) => switch (state) {
              ExchangeRateHistoryInitial() || ExchangeRateHistoryLoading() =>
                const Center(child: CircularProgressIndicator()),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorText(l10n, state.code), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => context.read<ExchangeRateHistoryBloc>().add(
                LoadHistory(
                  baseCurrency: baseCurrencyCode,
                  targetFilter: state.targetFilter,
                ),
              ),
              child: Text(l10n.retryButton),
            ),
          ],
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
    final targetCurrencies = currencies
        .where((currency) => currency.code != state.baseCurrency)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loadingMore) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.targetCurrencyFilterLabel),
              FilterChip(
                label: Text(l10n.targetCurrencyAnyLabel),
                selected: state.targetFilter == null,
                onSelected: (_) => context.read<ExchangeRateHistoryBloc>().add(
                  const TargetFilterChanged(null),
                ),
              ),
              for (final currency in targetCurrencies)
                FilterChip(
                  label: Text(currency.code),
                  selected: state.targetFilter == currency.code,
                  onSelected: (_) => context
                      .read<ExchangeRateHistoryBloc>()
                      .add(TargetFilterChanged(currency.code)),
                ),
            ],
          ),
        ),
        Expanded(
          child: state.rates.isEmpty
              ? Center(child: Text(l10n.noRatesYet))
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  itemCount: state.rates.length + (loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index >= state.rates.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ExchangeRateRow(exchangeRate: state.rates[index]);
                  },
                ),
        ),
      ],
    );
  }
}
