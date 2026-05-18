import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/repositories/currencies_repository_impl.dart'
    show CurrenciesFailure;
import '../../domain/entities/exchange_rate.dart';
import '../../domain/usecases/list_exchange_rate_history.dart';

sealed class ExchangeRateHistoryEvent extends Equatable {
  const ExchangeRateHistoryEvent();

  @override
  List<Object?> get props => [];
}

final class LoadHistory extends ExchangeRateHistoryEvent {
  const LoadHistory({required this.baseCurrency, this.targetFilter});

  final String baseCurrency;
  final String? targetFilter;

  @override
  List<Object?> get props => [baseCurrency, targetFilter];
}

final class LoadMore extends ExchangeRateHistoryEvent {
  const LoadMore();
}

final class TargetFilterChanged extends ExchangeRateHistoryEvent {
  const TargetFilterChanged(this.targetFilter);

  final String? targetFilter;

  @override
  List<Object?> get props => [targetFilter];
}

sealed class ExchangeRateHistoryState extends Equatable {
  const ExchangeRateHistoryState();

  @override
  List<Object?> get props => [];
}

final class ExchangeRateHistoryInitial extends ExchangeRateHistoryState {
  const ExchangeRateHistoryInitial();
}

final class ExchangeRateHistoryLoading extends ExchangeRateHistoryState {
  const ExchangeRateHistoryLoading();
}

final class ExchangeRateHistoryLoaded extends ExchangeRateHistoryState {
  const ExchangeRateHistoryLoaded({
    required this.baseCurrency,
    required this.targetFilter,
    required this.rates,
    required this.hasMore,
  });

  final String baseCurrency;
  final String? targetFilter;
  final List<ExchangeRate> rates;
  final bool hasMore;

  @override
  List<Object?> get props => [baseCurrency, targetFilter, rates, hasMore];
}

final class ExchangeRateHistoryLoadingMore extends ExchangeRateHistoryState {
  const ExchangeRateHistoryLoadingMore({required this.previous});

  final ExchangeRateHistoryLoaded previous;

  @override
  List<Object?> get props => [previous];
}

final class ExchangeRateHistoryError extends ExchangeRateHistoryState {
  const ExchangeRateHistoryError({
    required this.baseCurrency,
    required this.targetFilter,
    required this.code,
  });

  final String baseCurrency;
  final String? targetFilter;
  final String code;

  @override
  List<Object?> get props => [baseCurrency, targetFilter, code];
}

@injectable
class ExchangeRateHistoryBloc
    extends Bloc<ExchangeRateHistoryEvent, ExchangeRateHistoryState> {
  ExchangeRateHistoryBloc(this._listHistory)
    : super(const ExchangeRateHistoryInitial()) {
    on<LoadHistory>(_load);
    on<TargetFilterChanged>(_filterChanged);
    on<LoadMore>(_loadMore);
  }

  static const _pageSize = 50;

  final ListExchangeRateHistory _listHistory;

  Future<void> _load(
    LoadHistory event,
    Emitter<ExchangeRateHistoryState> emit,
  ) async {
    emit(const ExchangeRateHistoryLoading());
    await _fetchFirstPage(
      emit,
      baseCurrency: event.baseCurrency,
      targetFilter: event.targetFilter,
    );
  }

  Future<void> _filterChanged(
    TargetFilterChanged event,
    Emitter<ExchangeRateHistoryState> emit,
  ) async {
    final current = state;
    if (current is! ExchangeRateHistoryLoaded) return;
    if (current.targetFilter == event.targetFilter) return;
    emit(
      ExchangeRateHistoryLoadingMore(
        previous: ExchangeRateHistoryLoaded(
          baseCurrency: current.baseCurrency,
          targetFilter: event.targetFilter,
          rates: current.rates,
          hasMore: false,
        ),
      ),
    );
    await _fetchFirstPage(
      emit,
      baseCurrency: current.baseCurrency,
      targetFilter: event.targetFilter,
    );
  }

  Future<void> _fetchFirstPage(
    Emitter<ExchangeRateHistoryState> emit, {
    required String baseCurrency,
    required String? targetFilter,
  }) async {
    try {
      final rows = await _listHistory(
        baseCurrency: baseCurrency,
        targetCurrencyFilter: targetFilter,
        limit: _pageSize,
      );
      emit(
        ExchangeRateHistoryLoaded(
          baseCurrency: baseCurrency,
          targetFilter: targetFilter,
          rates: rows,
          hasMore: rows.length == _pageSize,
        ),
      );
    } on CurrenciesFailure catch (error) {
      emit(
        ExchangeRateHistoryError(
          baseCurrency: baseCurrency,
          targetFilter: targetFilter,
          code: error.code,
        ),
      );
    } on Object catch (_) {
      emit(
        ExchangeRateHistoryError(
          baseCurrency: baseCurrency,
          targetFilter: targetFilter,
          code: 'unknown',
        ),
      );
    }
  }

  Future<void> _loadMore(
    LoadMore event,
    Emitter<ExchangeRateHistoryState> emit,
  ) async {
    final current = state;
    if (current is! ExchangeRateHistoryLoaded || !current.hasMore) return;
    if (current.rates.isEmpty) return;

    emit(ExchangeRateHistoryLoadingMore(previous: current));
    try {
      final rows = await _listHistory(
        baseCurrency: current.baseCurrency,
        targetCurrencyFilter: current.targetFilter,
        cursorBefore: current.rates.last.createdAt,
        limit: _pageSize,
      );
      emit(
        ExchangeRateHistoryLoaded(
          baseCurrency: current.baseCurrency,
          targetFilter: current.targetFilter,
          rates: [...current.rates, ...rows],
          hasMore: rows.length == _pageSize,
        ),
      );
    } on CurrenciesFailure catch (error) {
      emit(
        ExchangeRateHistoryError(
          baseCurrency: current.baseCurrency,
          targetFilter: current.targetFilter,
          code: error.code,
        ),
      );
    } on Object catch (_) {
      emit(
        ExchangeRateHistoryError(
          baseCurrency: current.baseCurrency,
          targetFilter: current.targetFilter,
          code: 'unknown',
        ),
      );
    }
  }
}
