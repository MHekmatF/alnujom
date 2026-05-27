// lib/features/inquiries/presentation/bloc/inquiry_detail_state.dart
part of 'inquiry_detail_bloc.dart';

sealed class InquiryDetailState extends Equatable {
  const InquiryDetailState();

  @override
  List<Object?> get props => [];
}

/// Loading the inquiry from the server.
final class InquiryDetailLoading extends InquiryDetailState {
  const InquiryDetailLoading();
}

/// Inquiry loaded (and optionally updated optimistically).
final class InquiryDetailLoaded extends InquiryDetailState {
  const InquiryDetailLoaded({required this.inquiry});

  final Inquiry inquiry;

  @override
  List<Object?> get props => [inquiry];
}

/// Unrecoverable error. The page may offer a retry.
final class InquiryDetailError extends InquiryDetailState {
  const InquiryDetailError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
