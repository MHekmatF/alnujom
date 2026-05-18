import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/repositories/currencies_repository_impl.dart'
    show CurrenciesFailure;
import '../../domain/entities/currency_with_latest_rates.dart';
import '../../domain/usecases/list_currencies.dart';
import '../../domain/usecases/load_latest_rates_for_base.dart';

sealed class CurrenciesListEvent extends Equatable {
  const CurrenciesListEvent();

  @override
  List<Object?> get props => [];
}

final class LoadCurrencies extends CurrenciesListEvent {
  const LoadCurrencies();
}

final class RefreshCurrencies extends CurrenciesListEvent {
  const RefreshCurrencies();
}

final class CurrencyMutated extends CurrenciesListEvent {
  const CurrencyMutated(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

sealed class CurrenciesListState extends Equatable {
  const CurrenciesListState();

  @override
  List<Object?> get props => [];
}

final class CurrenciesListInitial extends CurrenciesListState {
  const CurrenciesListInitial();
}

final class CurrenciesListLoading extends CurrenciesListState {
  const CurrenciesListLoading();
}

final class CurrenciesListLoaded extends CurrenciesListState {
  const CurrenciesListLoaded(this.currencies);

  final List<CurrencyWithLatestRates> currencies;

  @override
  List<Object?> get props => [currencies];
}

final class CurrenciesListError extends CurrenciesListState {
  const CurrenciesListError(this.reason, this.technicalMessage);

  /// Stable error key (e.g. `'permission_denied'`, `'unknown'`) for page-level
  /// ARB mapping. Pages call a localizer; they MUST NOT show
  /// [technicalMessage] in production builds.
  final String reason;
  final String technicalMessage;

  @override
  List<Object?> get props => [reason, technicalMessage];
}

@injectable
class CurrenciesListBloc
    extends Bloc<CurrenciesListEvent, CurrenciesListState> {
  CurrenciesListBloc(this._listCurrencies, this._loadLatestRatesForBase)
    : super(const CurrenciesListInitial()) {
    on<LoadCurrencies>(_load);
    on<RefreshCurrencies>(_load);
    on<CurrencyMutated>(_load);
  }

  final ListCurrencies _listCurrencies;
  final LoadLatestRatesForBase _loadLatestRatesForBase;

  Future<void> _load(
    CurrenciesListEvent event,
    Emitter<CurrenciesListState> emit,
  ) async {
    emit(const CurrenciesListLoading());
    try {
      final currencies = await _listCurrencies();
      // Parallel fan-out (D): N RPC calls dispatched together instead of in
      // sequence. For 2 currencies the savings are small but correct.
      final rates = await Future.wait(
        currencies.map((c) => _loadLatestRatesForBase(c.code)),
      );
      final summaries = [
        for (var i = 0; i < currencies.length; i++)
          CurrencyWithLatestRates(
            currency: currencies[i],
            latestRates: rates[i],
          ),
      ];
      emit(CurrenciesListLoaded(summaries));
    } on CurrenciesFailure catch (error) {
      emit(CurrenciesListError(error.code, error.technicalMessage));
    } on Object catch (error) {
      emit(CurrenciesListError('unknown', error.toString()));
    }
  }
}
