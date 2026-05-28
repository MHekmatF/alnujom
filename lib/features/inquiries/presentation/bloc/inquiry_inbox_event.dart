// lib/features/inquiries/presentation/bloc/inquiry_inbox_event.dart
part of 'inquiry_inbox_bloc.dart';

sealed class InquiryInboxEvent extends Equatable {
  const InquiryInboxEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched when the inbox page first mounts.
///
/// [adminTier] = false (default) → personal publisher inbox: only inquiries on
/// listings the viewer publishes (filtered by `viewer_is_publisher`). This
/// matters for admin users, whose RLS would otherwise surface ALL inquiries
/// in their personal inbox. [adminTier] = true → admin oversight: all rows.
final class InquiryInboxOpened extends InquiryInboxEvent {
  const InquiryInboxOpened({this.adminTier = false});

  final bool adminTier;

  @override
  List<Object?> get props => [adminTier];
}

/// Dispatched by the RefreshIndicator pull-to-refresh.
final class InquiryInboxRefreshRequested extends InquiryInboxEvent {
  const InquiryInboxRefreshRequested();
}

/// Dispatched when the ListView scroll crosses the 80 % threshold.
final class InquiryInboxMoreLoaded extends InquiryInboxEvent {
  const InquiryInboxMoreLoaded();
}

/// Dispatched when the status filter dropdown changes. Null = "all statuses".
final class InquiryInboxStatusFilterChanged extends InquiryInboxEvent {
  const InquiryInboxStatusFilterChanged(this.status);

  final InquiryStatus? status;

  @override
  List<Object?> get props => [status];
}

/// Dispatched when the listing filter dropdown changes. Null = "all listings".
final class InquiryInboxListingFilterChanged extends InquiryInboxEvent {
  const InquiryInboxListingFilterChanged(this.listingId);

  final String? listingId;

  @override
  List<Object?> get props => [listingId];
}
