// lib/features/inquiries/presentation/bloc/inquiry_form_state.dart
part of 'inquiry_form_bloc.dart';

sealed class InquiryFormState extends Equatable {
  const InquiryFormState();

  @override
  List<Object?> get props => [];
}

/// The form is being edited. Carries current field values + per-field errors.
final class InquiryFormEditing extends InquiryFormState {
  const InquiryFormEditing({
    required this.name,
    required this.phone,
    required this.message,
    this.validationErrors = const {},
  });

  final String name;
  final String phone;
  final String message;

  /// Keys are field names ('name', 'phone', 'message', '_' for general).
  /// Values are localization-key-style codes (e.g. 'invalid_sender_name').
  final Map<String, String> validationErrors;

  InquiryFormEditing copyWith({
    String? name,
    String? phone,
    String? message,
    Map<String, String>? validationErrors,
  }) => InquiryFormEditing(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    message: message ?? this.message,
    validationErrors: validationErrors ?? this.validationErrors,
  );

  @override
  List<Object?> get props => [name, phone, message, validationErrors];
}

/// The form has been submitted and the RPC is in flight.
final class InquiryFormSubmitting extends InquiryFormState {
  const InquiryFormSubmitting();
}

/// The RPC succeeded. The sheet should close and a snackbar should appear.
final class InquiryFormSubmittedSuccess extends InquiryFormState {
  const InquiryFormSubmittedSuccess({required this.inquiryId});

  final String inquiryId;

  @override
  List<Object?> get props => [inquiryId];
}

/// The RPC failed. The sheet stays open for a retry.
final class InquiryFormFailed extends InquiryFormState {
  const InquiryFormFailed({required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
