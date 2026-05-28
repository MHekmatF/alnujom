// lib/features/inquiries/presentation/bloc/inquiry_inbox_state.dart
part of 'inquiry_inbox_bloc.dart';

sealed class InquiryInboxState extends Equatable {
  const InquiryInboxState();

  @override
  List<Object?> get props => [];
}

/// Initial state / refresh in flight.
final class InquiryInboxLoading extends InquiryInboxState {
  const InquiryInboxLoading();
}

/// Data loaded; the list may be empty (empty-state UI) or non-empty.
final class InquiryInboxLoaded extends InquiryInboxState {
  const InquiryInboxLoaded({
    required this.inquiries,
    required this.hasMore,
    this.cursor,
    this.statusFilter,
    this.listingFilter,
  });

  final List<Inquiry> inquiries;
  final bool hasMore;

  /// Cursor for the next page — null when no more pages exist.
  final String? cursor;
  final InquiryStatus? statusFilter;
  final String? listingFilter;

  InquiryInboxLoaded copyWith({
    List<Inquiry>? inquiries,
    bool? hasMore,
    String? cursor,
    InquiryStatus? statusFilter,
    String? listingFilter,
  }) => InquiryInboxLoaded(
    inquiries: inquiries ?? this.inquiries,
    hasMore: hasMore ?? this.hasMore,
    cursor: cursor ?? this.cursor,
    statusFilter: statusFilter ?? this.statusFilter,
    listingFilter: listingFilter ?? this.listingFilter,
  );

  @override
  List<Object?> get props => [
    inquiries,
    hasMore,
    cursor,
    statusFilter,
    listingFilter,
  ];
}

/// Terminal error state — the user retries via the error view's button.
final class InquiryInboxError extends InquiryInboxState {
  const InquiryInboxError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
