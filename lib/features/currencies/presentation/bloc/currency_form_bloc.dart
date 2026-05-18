import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/repositories/currencies_repository_impl.dart'
    show CurrenciesFailure;
import '../../domain/entities/currency.dart';
import '../../domain/usecases/create_currency.dart';
import '../../domain/usecases/load_currency_detail.dart';
import '../../domain/usecases/update_currency.dart';

enum FormMode { create, edit }

enum CurrencyFormStatus {
  idle,
  loading,
  validating,
  saving,
  saveSuccess,
  saveFailure,
}

sealed class CurrencyFormEvent extends Equatable {
  const CurrencyFormEvent();

  @override
  List<Object?> get props => [];
}

final class Initialize extends CurrencyFormEvent {
  const Initialize(this.mode, {this.code});

  final FormMode mode;
  final String? code;

  @override
  List<Object?> get props => [mode, code];
}

final class EditFieldChanged extends CurrencyFormEvent {
  const EditFieldChanged(this.name, this.value);

  final String name;
  final Object? value;

  @override
  List<Object?> get props => [name, value];
}

final class SubmitPressed extends CurrencyFormEvent {
  const SubmitPressed();
}

const _sentinel = Object();

class CurrencyFormState extends Equatable {
  const CurrencyFormState({
    required this.mode,
    required this.fieldValues,
    this.status = CurrencyFormStatus.idle,
    this.loadedCurrency,
    this.savedCurrency,
    this.failureReason,
  });

  factory CurrencyFormState.initial() => const CurrencyFormState(
    mode: FormMode.create,
    fieldValues: {
      'code': '',
      'nameAr': '',
      'nameEn': '',
      'symbol': '',
      'sortOrder': 100,
      'displayDecimals': 2,
      'isActive': true,
    },
  );

  final FormMode mode;
  final Map<String, Object?> fieldValues;
  final CurrencyFormStatus status;
  final Currency? loadedCurrency;
  final Currency? savedCurrency;

  /// Stable error key (e.g. `'permission_denied'`, `'duplicate_code'`,
  /// `'system_immutable'`, `'validation_failed'`). Mapped by the page to a
  /// localized message.
  final String? failureReason;

  bool get isLoading => status == CurrencyFormStatus.loading;
  bool get isSaving => status == CurrencyFormStatus.saving;
  bool get isLoadedSystemRow => loadedCurrency?.isSystem ?? false;

  CurrencyFormState copyWith({
    FormMode? mode,
    Map<String, Object?>? fieldValues,
    CurrencyFormStatus? status,
    Object? loadedCurrency = _sentinel,
    Object? savedCurrency = _sentinel,
    Object? failureReason = _sentinel,
  }) {
    return CurrencyFormState(
      mode: mode ?? this.mode,
      fieldValues: fieldValues ?? this.fieldValues,
      status: status ?? this.status,
      loadedCurrency: loadedCurrency == _sentinel
          ? this.loadedCurrency
          : loadedCurrency as Currency?,
      savedCurrency: savedCurrency == _sentinel
          ? this.savedCurrency
          : savedCurrency as Currency?,
      failureReason: failureReason == _sentinel
          ? this.failureReason
          : failureReason as String?,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    fieldValues,
    status,
    loadedCurrency,
    savedCurrency,
    failureReason,
  ];
}

@injectable
class CurrencyFormBloc extends Bloc<CurrencyFormEvent, CurrencyFormState> {
  CurrencyFormBloc(
    this._createCurrency,
    this._updateCurrency,
    this._loadCurrencyDetail,
  ) : super(CurrencyFormState.initial()) {
    on<Initialize>(_initialize);
    on<EditFieldChanged>(_fieldChanged);
    on<SubmitPressed>(_submit);
  }

  final CreateCurrency _createCurrency;
  final UpdateCurrency _updateCurrency;
  final LoadCurrencyDetail _loadCurrencyDetail;

  Future<void> _initialize(
    Initialize event,
    Emitter<CurrencyFormState> emit,
  ) async {
    if (event.mode == FormMode.create) {
      emit(CurrencyFormState.initial());
      return;
    }

    final code = event.code;
    if (code == null || code.isEmpty) {
      emit(
        state.copyWith(
          mode: FormMode.edit,
          status: CurrencyFormStatus.saveFailure,
          failureReason: 'validation_failed',
        ),
      );
      return;
    }

    // Distinct loading status (F): separate from `saving` so the page can show
    // a "loading existing data" indicator without disabling the (yet-empty)
    // form fields the way Saving does.
    emit(
      state.copyWith(mode: FormMode.edit, status: CurrencyFormStatus.loading),
    );
    try {
      final currency = await _loadCurrencyDetail(code);
      emit(
        CurrencyFormState(
          mode: FormMode.edit,
          loadedCurrency: currency,
          fieldValues: {
            'code': currency.code,
            'nameAr': currency.nameAr,
            'nameEn': currency.nameEn,
            'symbol': currency.symbol,
            'sortOrder': currency.sortOrder,
            'displayDecimals': currency.displayDecimals,
            'isActive': currency.isActive,
          },
        ),
      );
    } on CurrenciesFailure catch (error) {
      emit(
        state.copyWith(
          mode: FormMode.edit,
          status: CurrencyFormStatus.saveFailure,
          failureReason: error.code,
        ),
      );
    } on Object catch (_) {
      emit(
        state.copyWith(
          mode: FormMode.edit,
          status: CurrencyFormStatus.saveFailure,
          failureReason: 'unknown',
        ),
      );
    }
  }

  void _fieldChanged(EditFieldChanged event, Emitter<CurrencyFormState> emit) {
    final values = Map<String, Object?>.of(state.fieldValues);
    values[event.name] = event.value;
    emit(
      state.copyWith(
        fieldValues: values,
        status: CurrencyFormStatus.idle,
        failureReason: null,
      ),
    );
  }

  Future<void> _submit(
    SubmitPressed event,
    Emitter<CurrencyFormState> emit,
  ) async {
    if (state.isSaving) return;
    emit(state.copyWith(status: CurrencyFormStatus.validating));

    final code = _string('code').trim().toUpperCase();
    final nameAr = _string('nameAr').trim();
    final nameEn = _string('nameEn').trim();
    final symbol = _string('symbol').trim();
    final sortOrder = _int('sortOrder') ?? 100;
    final displayDecimals = _int('displayDecimals') ?? 2;
    final isActive = _bool('isActive');

    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code) ||
        nameAr.isEmpty ||
        nameEn.isEmpty ||
        symbol.isEmpty ||
        displayDecimals < 0 ||
        displayDecimals > 8) {
      emit(
        state.copyWith(
          status: CurrencyFormStatus.saveFailure,
          failureReason: 'validation_failed',
        ),
      );
      return;
    }

    emit(state.copyWith(status: CurrencyFormStatus.saving));
    try {
      final Currency saved;
      if (state.mode == FormMode.create) {
        saved = await _createCurrency(
          code: code,
          nameAr: nameAr,
          nameEn: nameEn,
          symbol: symbol,
          sortOrder: sortOrder,
          displayDecimals: displayDecimals,
          isActive: isActive,
        );
      } else {
        final loaded = state.loadedCurrency;
        saved = await _updateCurrency(
          Currency(
            code: loaded?.code ?? code,
            nameAr: nameAr,
            nameEn: nameEn,
            symbol: symbol,
            isActive: isActive,
            sortOrder: sortOrder,
            isSystem: loaded?.isSystem ?? false,
            displayDecimals: displayDecimals,
            createdAt: loaded?.createdAt ?? DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
      emit(
        state.copyWith(
          status: CurrencyFormStatus.saveSuccess,
          savedCurrency: saved,
        ),
      );
    } on CurrenciesFailure catch (error) {
      emit(
        state.copyWith(
          status: CurrencyFormStatus.saveFailure,
          failureReason: error.code,
        ),
      );
    } on Object catch (_) {
      emit(
        state.copyWith(
          status: CurrencyFormStatus.saveFailure,
          failureReason: 'unknown',
        ),
      );
    }
  }

  String _string(String key) => state.fieldValues[key]?.toString() ?? '';

  int? _int(String key) {
    final value = state.fieldValues[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  bool _bool(String key) => state.fieldValues[key] == true;
}
