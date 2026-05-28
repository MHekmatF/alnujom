// lib/features/inquiries/presentation/bloc/inquiry_form_event.dart
part of 'inquiry_form_bloc.dart';

/// Identifies which field in the inquiry form changed.
enum InquiryFormField { name, phone, message }

sealed class InquiryFormEvent extends Equatable {
  const InquiryFormEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on every keystroke in any of the three fields.
final class InquiryFormFieldChanged extends InquiryFormEvent {
  const InquiryFormFieldChanged({required this.field, required this.value});

  final InquiryFormField field;
  final String value;

  @override
  List<Object?> get props => [field, value];
}

/// Dispatched when the user taps the submit button.
final class InquiryFormSubmitted extends InquiryFormEvent {
  const InquiryFormSubmitted();
}
