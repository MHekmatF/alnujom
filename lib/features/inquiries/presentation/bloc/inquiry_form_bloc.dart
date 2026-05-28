// lib/features/inquiries/presentation/bloc/inquiry_form_bloc.dart
//
// Phase 16 Sub-Phase F (T061) — BLoC driving the InquiryFormSheet.
// Factory-scoped: one instance per sheet open (param1 = listingId).
//
// Validation is delegated to InquirySubmission.validate(...) which returns
// a typed ValidationFailure carrying an opaque code. The BLoC maps those
// codes to the field-level error map consumed by the sheet's TextFields.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/inquiry_submission.dart';
import '../../domain/usecases/submit_inquiry.dart';

part 'inquiry_form_event.dart';
part 'inquiry_form_state.dart';

@injectable
class InquiryFormBloc extends Bloc<InquiryFormEvent, InquiryFormState> {
  InquiryFormBloc(this._submitInquiry, @factoryParam this._listingId)
    : super(const InquiryFormEditing(name: '', phone: '', message: '')) {
    on<InquiryFormFieldChanged>(_onFieldChanged);
    on<InquiryFormSubmitted>(_onSubmitted);
  }

  final SubmitInquiry _submitInquiry;
  final String _listingId;

  void _onFieldChanged(
    InquiryFormFieldChanged event,
    Emitter<InquiryFormState> emit,
  ) {
    if (state is! InquiryFormEditing) return;
    final editing = state as InquiryFormEditing;
    final updated = switch (event.field) {
      InquiryFormField.name => editing.copyWith(name: event.value),
      InquiryFormField.phone => editing.copyWith(phone: event.value),
      InquiryFormField.message => editing.copyWith(message: event.value),
    };
    emit(updated);
  }

  Future<void> _onSubmitted(
    InquiryFormSubmitted event,
    Emitter<InquiryFormState> emit,
  ) async {
    if (state is! InquiryFormEditing) return;
    final editing = state as InquiryFormEditing;

    // First pass: build InquirySubmission via validate() — returns typed errors.
    final validationResult = InquirySubmission.validate(
      listingId: _listingId,
      senderName: editing.name,
      phone: editing.phone,
      message: editing.message,
    );

    if (validationResult case FailureResult<InquirySubmission>(
      :final failure,
    )) {
      // Map validation code → per-field error map.
      final errors = _mapValidationCode(
        failure is ValidationFailure ? failure.code : 'unknown',
        editing,
      );
      emit(editing.copyWith(validationErrors: errors));
      return;
    }

    emit(const InquiryFormSubmitting());

    final submission = (validationResult as Success<InquirySubmission>).value;
    final result = await _submitInquiry(submission);

    switch (result) {
      case Success<String>(:final value):
        emit(InquiryFormSubmittedSuccess(inquiryId: value));
      case FailureResult<String>(:final failure):
        emit(InquiryFormFailed(failure: failure));
    }
  }

  /// Translates a [ValidationFailure.code] into a field-keyed error map.
  Map<String, String> _mapValidationCode(
    String code,
    InquiryFormEditing editing,
  ) {
    return switch (code) {
      'invalid_sender_name' => {'name': code},
      'invalid_phone' => {'phone': code},
      'invalid_message_length' => {'message': code},
      _ => {'_': code},
    };
  }
}
