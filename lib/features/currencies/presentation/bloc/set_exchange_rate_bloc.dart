import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../shared/util/decimal_round.dart';
import '../../data/repositories/currencies_repository_impl.dart'
    show CurrenciesFailure;
import '../../domain/entities/update_exchange_rate_result.dart';
import '../../domain/usecases/set_exchange_rate.dart';

enum SetRateStatus {
  idle,
  saving,
  saveSuccess,
  saveFailure,
  unusualTimingPending,
}

sealed class SetExchangeRateEvent extends Equatable {
  const SetExchangeRateEvent();

  @override
  List<Object?> get props => [];
}

final class BaseChanged extends SetExchangeRateEvent {
  const BaseChanged(this.code);

  final String? code;

  @override
  List<Object?> get props => [code];
}

final class TargetChanged extends SetExchangeRateEvent {
  const TargetChanged(this.code);

  final String? code;

  @override
  List<Object?> get props => [code];
}

final class RateChanged extends SetExchangeRateEvent {
  const RateChanged(this.rate);

  final Decimal? rate;

  @override
  List<Object?> get props => [rate];
}

final class EffectiveAtChanged extends SetExchangeRateEvent {
  const EffectiveAtChanged(this.effectiveAt);

  final DateTime effectiveAt;

  @override
  List<Object?> get props => [effectiveAt];
}

final class SourceChanged extends SetExchangeRateEvent {
  const SourceChanged(this.sourceText);

  final String? sourceText;

  @override
  List<Object?> get props => [sourceText];
}

final class SetRateSubmitPressed extends SetExchangeRateEvent {
  const SetRateSubmitPressed();
}

final class UnusualTimingConfirmed extends SetExchangeRateEvent {
  const UnusualTimingConfirmed();
}

final class UnusualTimingCancelled extends SetExchangeRateEvent {
  const UnusualTimingCancelled();
}

class SetExchangeRateState extends Equatable {
  const SetExchangeRateState({
    this.baseCurrency,
    this.targetCurrency,
    this.rate,
    required this.effectiveAt,
    this.sourceText,
    this.derivedRatePreview,
    this.status = SetRateStatus.idle,
    this.failureReason,
    this.saveResult,
  });

  factory SetExchangeRateState.initial() =>
      SetExchangeRateState(effectiveAt: DateTime.now());

  final String? baseCurrency;
  final String? targetCurrency;
  final Decimal? rate;
  final DateTime effectiveAt;
  final String? sourceText;
  final Decimal? derivedRatePreview;
  final SetRateStatus status;

  /// Stable error key (e.g. `'rate_must_be_positive'`, `'base_equals_target'`,
  /// `'permission_denied'`, `'unknown'`). Mapped by the page to a localized
  /// message.
  final String? failureReason;
  final UpdateExchangeRateResult? saveResult;

  SetExchangeRateState copyWith({
    Object? baseCurrency = _sentinel,
    Object? targetCurrency = _sentinel,
    Object? rate = _sentinel,
    DateTime? effectiveAt,
    Object? sourceText = _sentinel,
    Object? derivedRatePreview = _sentinel,
    SetRateStatus? status,
    Object? failureReason = _sentinel,
    Object? saveResult = _sentinel,
  }) {
    return SetExchangeRateState(
      baseCurrency: baseCurrency == _sentinel
          ? this.baseCurrency
          : baseCurrency as String?,
      targetCurrency: targetCurrency == _sentinel
          ? this.targetCurrency
          : targetCurrency as String?,
      rate: rate == _sentinel ? this.rate : rate as Decimal?,
      effectiveAt: effectiveAt ?? this.effectiveAt,
      sourceText: sourceText == _sentinel
          ? this.sourceText
          : sourceText as String?,
      derivedRatePreview: derivedRatePreview == _sentinel
          ? this.derivedRatePreview
          : derivedRatePreview as Decimal?,
      status: status ?? this.status,
      failureReason: failureReason == _sentinel
          ? this.failureReason
          : failureReason as String?,
      saveResult: saveResult == _sentinel
          ? this.saveResult
          : saveResult as UpdateExchangeRateResult?,
    );
  }

  @override
  List<Object?> get props => [
    baseCurrency,
    targetCurrency,
    rate,
    effectiveAt,
    sourceText,
    derivedRatePreview,
    status,
    failureReason,
    saveResult,
  ];
}

const _sentinel = Object();

@injectable
class SetExchangeRateBloc
    extends Bloc<SetExchangeRateEvent, SetExchangeRateState> {
  SetExchangeRateBloc(this._setExchangeRate)
    : super(SetExchangeRateState.initial()) {
    on<BaseChanged>(
      (event, emit) => emit(state.copyWith(baseCurrency: event.code)),
    );
    on<TargetChanged>(
      (event, emit) => emit(state.copyWith(targetCurrency: event.code)),
    );
    on<RateChanged>(_rateChanged);
    on<EffectiveAtChanged>(
      (event, emit) => emit(state.copyWith(effectiveAt: event.effectiveAt)),
    );
    on<SourceChanged>(
      (event, emit) => emit(state.copyWith(sourceText: event.sourceText)),
    );
    on<SetRateSubmitPressed>(_submit);
    on<UnusualTimingConfirmed>(_confirmed);
    on<UnusualTimingCancelled>(
      (event, emit) => emit(
        state.copyWith(
          status: SetRateStatus.idle,
          failureReason: null,
        ),
      ),
    );
  }

  final SetExchangeRate _setExchangeRate;

  void _rateChanged(RateChanged event, Emitter<SetExchangeRateState> emit) {
    final rate = event.rate;
    // Preview rounding (Concern A): match what Postgres `round()` will store,
    // not banker's. So the preview value displayed before submit equals the
    // value the DB will hold after submit. R-11 keeps banker's at the *display*
    // layer (MoneyFormatter), but this is a *derivation* operation predicting
    // storage — half-away-from-zero is correct here.
    final preview = rate == null || rate <= Decimal.zero
        ? null
        : roundHalfAwayFromZero(
            (Decimal.one / rate).toDecimal(scaleOnInfinitePrecision: 12),
            6,
          );
    emit(state.copyWith(rate: rate, derivedRatePreview: preview));
  }

  Future<void> _submit(
    SetRateSubmitPressed event,
    Emitter<SetExchangeRateState> emit,
  ) async {
    final failure = _validationFailure();
    if (failure != null) {
      emit(
        state.copyWith(
          status: SetRateStatus.saveFailure,
          failureReason: failure,
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (state.effectiveAt.isAfter(now.add(const Duration(hours: 24))) ||
        state.effectiveAt.isBefore(now.subtract(const Duration(hours: 24)))) {
      emit(state.copyWith(status: SetRateStatus.unusualTimingPending));
      return;
    }

    await _save(emit);
  }

  Future<void> _confirmed(
    UnusualTimingConfirmed event,
    Emitter<SetExchangeRateState> emit,
  ) async {
    final failure = _validationFailure();
    if (failure != null) {
      emit(
        state.copyWith(
          status: SetRateStatus.saveFailure,
          failureReason: failure,
        ),
      );
      return;
    }
    await _save(emit);
  }

  Future<void> _save(Emitter<SetExchangeRateState> emit) async {
    emit(state.copyWith(status: SetRateStatus.saving, failureReason: null));
    try {
      final result = await _setExchangeRate(
        baseCurrency: state.baseCurrency!,
        targetCurrency: state.targetCurrency!,
        rate: state.rate!,
        effectiveAt: state.effectiveAt,
        source: state.sourceText?.trim().isEmpty == true
            ? null
            : state.sourceText?.trim(),
      );
      emit(
        state.copyWith(status: SetRateStatus.saveSuccess, saveResult: result),
      );
    } on CurrenciesFailure catch (error) {
      emit(
        state.copyWith(
          status: SetRateStatus.saveFailure,
          failureReason: error.code,
        ),
      );
    } on Object catch (_) {
      emit(
        state.copyWith(
          status: SetRateStatus.saveFailure,
          failureReason: 'unknown',
        ),
      );
    }
  }

  String? _validationFailure() {
    if (state.baseCurrency == null || state.targetCurrency == null) {
      return 'validation_failed';
    }
    if (state.baseCurrency == state.targetCurrency) return 'base_equals_target';
    final rate = state.rate;
    if (rate == null || rate <= Decimal.zero) return 'rate_must_be_positive';
    return null;
  }
}
